#!/bin/bash

set -e

# 使用方法を表示する関数
usage() {
    echo "使用方法: $0 <app_id> <output_file>"
    echo "  <app_id>: OneLoginアプリケーションID"
    echo "  <output_file>: 出力するTerraformファイル名"
    exit 1
}

# 引数のチェック
if [ "$#" -ne 2 ]; then
    usage
fi

APP_ID=$1
OUTPUT_FILE=$2
TEMP_CONFIG="temp_config.tf"

# 認証情報は環境変数から取得する（プロバイダーと同じもの）
for v in ONELOGIN_CLIENT_ID ONELOGIN_CLIENT_SECRET ONELOGIN_API_URL; do
    if [ -z "${!v}" ]; then
        echo "Error: 環境変数 $v が設定されていません。"
        exit 1
    fi
done
API_URL="${ONELOGIN_API_URL%/}"

# アクセストークンを取得する（表示・保存はしない）
API_KEY=$(curl -s -X POST "$API_URL/auth/oauth2/v2/token" \
    -H "Content-Type: application/json" \
    -H "Authorization: client_id:$ONELOGIN_CLIENT_ID,client_secret:$ONELOGIN_CLIENT_SECRET" \
    -d '{"grant_type": "client_credentials"}' | jq -r '.access_token // empty')

if [ -z "$API_KEY" ]; then
    echo "Error: アクセストークンを取得できませんでした。クライアント ID・シークレット・API の URL を確認してください。"
    exit 1
fi

# Terraformの初期化
terraform init

# OneLogin APIからルールを取得
echo "アプリID: $APP_ID のルールを取得中..."
RULES=$(curl -s -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" "$API_URL/api/2/apps/$APP_ID/rules")

# APIレスポンスの検証
if ! echo "$RULES" | jq . >/dev/null 2>&1; then
    echo "Error: APIからの応答が有効なJSONではありません。応答内容:"
    echo "$RULES"
    exit 1
fi

# データの存在確認
if [ "$(echo "$RULES" | jq 'length')" == "0" ]; then
    echo "Error: APIレスポンスにデータが含まれていません。応答内容:"
    echo "$RULES"
    exit 1
fi

# 出力ファイルを初期化
echo "# OneLogin App Rules" > "$OUTPUT_FILE"

# ルールごとにTerraformリソースを作成
echo "$RULES" | jq -c '.[]' | while read -r rule; do
    RULE_ID=$(echo $rule | jq -r '.id')
    echo "ルール処理中: $RULE_ID"
    
    # リソースが既に存在するか確認
    if terraform state list | grep -q "onelogin_app_rules.rule_${RULE_ID}"; then
        echo "リソース onelogin_app_rules.rule_${RULE_ID} は既に存在します。状態から削除します。"
        terraform state rm "onelogin_app_rules.rule_${RULE_ID}"
    fi
    
    # 一時的な設定ファイルを作成
    cat << EOF > "$TEMP_CONFIG"
resource "onelogin_app_rules" "rule_${RULE_ID}" {
  # Temporary configuration for import
}
EOF

    # Terraformからリソースをインポート
    if terraform import -config=. "onelogin_app_rules.rule_${RULE_ID}" "${APP_ID}/${RULE_ID}"; then
        # インポートが成功した場合、リソースをファイルに書き込む
        
        # ルールの詳細を取得
        NAME=$(echo $rule | jq -r '.name')
        MATCH=$(echo $rule | jq -r '.match')
        ENABLED=$(echo $rule | jq -r '.enabled')
        POSITION=$(echo $rule | jq -r '.position')
        
        # Terraformリソースを作成
        cat << EOF >> "$OUTPUT_FILE"
resource "onelogin_app_rules" "rule_${RULE_ID}" {
  app_id   = "$APP_ID"
  enabled  = $ENABLED
  match    = "$MATCH"
  name     = "$NAME"
  position = $POSITION

EOF

        # アクションを追加
        echo $rule | jq -c '.actions[]' | while read -r action; do
            ACTION_TYPE=$(echo $action | jq -r '.action')
            ACTION_VALUE=$(echo $action | jq -r '.value | @json')
            echo "  actions {
    action = \"$ACTION_TYPE\"
    value  = $ACTION_VALUE
  }" >> "$OUTPUT_FILE"
        done

        # コンディションを追加
        echo $rule | jq -c '.conditions[]' | while read -r condition; do
            CONDITION_SOURCE=$(echo $condition | jq -r '.source')
            CONDITION_OPERATOR=$(echo $condition | jq -r '.operator')
            CONDITION_VALUE=$(echo $condition | jq -r '.value')
            echo "  conditions {
    operator = \"$CONDITION_OPERATOR\"
    source   = \"$CONDITION_SOURCE\"
    value    = \"$CONDITION_VALUE\"
  }" >> "$OUTPUT_FILE"
        done

        # リソースの終了
        echo "}" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        
        echo "ルール $RULE_ID のインポートと書き込みが成功しました。"
    else
        echo "Warning: ルール $RULE_ID のインポートに失敗しました。このルールはスキップされます。"
    fi
    
    # 一時的な設定ファイルを削除
    rm "$TEMP_CONFIG"
done

echo "
スクリプトの実行が完了しました。
- 正常にインポートされたTerraformリソースの定義が $OUTPUT_FILE に書き込まれました。
- インポートに失敗したルールは出力ファイルに含まれていません。
- 詳細はログを確認してください。
"
