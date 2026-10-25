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

# アクセストークンを取得する（表示・保存はしない）。
# 認証情報は curl の引数に出さず、標準入力（ヘッダー）で渡す（ps で他のユーザーに見えないようにするため）
API_KEY=$(curl -s -X POST "$API_URL/auth/oauth2/v2/token" \
    -H "Content-Type: application/json" -H @- \
    -d '{"grant_type": "client_credentials"}' \
    <<<"Authorization: client_id:$ONELOGIN_CLIENT_ID,client_secret:$ONELOGIN_CLIENT_SECRET" | jq -r '.access_token // empty')

if [ -z "$API_KEY" ]; then
    echo "Error: アクセストークンを取得できませんでした。クライアント ID・シークレット・API の URL を確認してください。"
    exit 1
fi

# Terraformの初期化
terraform init

# OneLogin APIからルールを取得
echo "アプリID: $APP_ID のルールを取得中..."
RULES=$(curl -s -H "Content-Type: application/json" -H @- "$API_URL/api/2/apps/$APP_ID/rules" <<<"Authorization: Bearer $API_KEY")

# APIレスポンスの検証（成功時は配列。エラー時は JSON オブジェクトが返るので、配列でなければ止める）
if ! echo "$RULES" | jq -e 'type == "array"' >/dev/null 2>&1; then
    echo "Error: APIからの応答がルールの一覧ではありません。応答内容:"
    echo "$RULES"
    exit 1
fi

# データの存在確認
if [ "$(echo "$RULES" | jq 'length')" == "0" ]; then
    echo "Error: APIレスポンスにデータが含まれていません。応答内容:"
    echo "$RULES"
    exit 1
fi

# ルール1件を、Terraform のリソース定義にする jq のプログラム。
# 値は tojson で HCL の文字列リテラルにし、${ と %{ は、Terraform が補間・テンプレートとして解釈しないようにエスケープする。
# actions / conditions は、API が返す項目（expression・macro・scriptlet を含む）をすべて書き出す
RULE_TO_HCL='
def s: tojson | gsub("\\$\\{"; "$${") | gsub("%\\{"; "%%{");
def opt($k): if (.[$k] // "") == "" then "" else "    \($k) = \(.[$k] | tostring | s)\n" end;
"resource \"onelogin_app_rules\" \"rule_\(.id)\" {\n"
+ "  app_id   = \($app | s)\n"
+ "  enabled  = \(.enabled)\n"
+ "  match    = \(.match | s)\n"
+ "  name     = \(.name | s)\n"
+ "  position = \(.position)\n\n"
+ ([.actions[]? |
    "  actions {\n"
    + "    action = \(.action | tostring | s)\n"
    + "    value  = \([.value // empty] | flatten | map(tostring) | s)\n"
    + opt("expression") + opt("scriptlet") + opt("macro")
    + "  }\n"] | join(""))
+ ([.conditions[]? |
    "  conditions {\n"
    + "    operator = \(.operator | tostring | s)\n"
    + "    source   = \(.source | tostring | s)\n"
    + "    value    = \(.value | tostring | s)\n"
    + "  }\n"] | join(""))
+ "}\n\n"
'

# 出力ファイルを初期化
echo "# OneLogin App Rules" > "$OUTPUT_FILE"

# ルールごとにTerraformリソースを作成
echo "$RULES" | jq -c '.[]' | while read -r rule; do
    RULE_ID=$(printf '%s' "$rule" | jq -r '.id')
    echo "ルール処理中: $RULE_ID"

    # リソースが既に存在するか確認（アドレスの完全一致。rule_12 が rule_123 に当たらないようにする）
    if terraform state list </dev/null | grep -Fxq "onelogin_app_rules.rule_${RULE_ID}"; then
        echo "リソース onelogin_app_rules.rule_${RULE_ID} は既に存在します。状態から削除します。"
        terraform state rm "onelogin_app_rules.rule_${RULE_ID}" </dev/null
    fi

    # 一時的な設定ファイルを作成
    cat << EOF > "$TEMP_CONFIG"
resource "onelogin_app_rules" "rule_${RULE_ID}" {
  # Temporary configuration for import
}
EOF

    # Terraformからリソースをインポート（ループの標準入力を読まないよう、/dev/null を渡す）
    if terraform import -config=. "onelogin_app_rules.rule_${RULE_ID}" "${APP_ID}/${RULE_ID}" </dev/null; then
        # インポートが成功した場合、リソースをファイルに書き込む
        printf '%s' "$rule" | jq -r --arg app "$APP_ID" "$RULE_TO_HCL" >> "$OUTPUT_FILE"
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
