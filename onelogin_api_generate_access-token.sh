#!/bin/bash

# .envファイルを読み込む
source .env

# 変数が正しく設定されているか確認
# echo "CLIENT_ID: $CLIENT_ID"
# echo "CLIENT_SECRET: $CLIENT_SECRET"
# echo "SUBDOMAIN: $SUBDOMAIN"

# OneLogin APIにアクセストークンをリクエスト
access_token=$(curl -s -X POST "https://$SUBDOMAIN.onelogin.com/auth/oauth2/v2/token" \
-H "Content-Type: application/json" \
-H "Authorization: client_id:$CLIENT_ID,client_secret:$CLIENT_SECRET" \
-d '{
"grant_type": "client_credentials"
}' | jq -r '.access_token')

# 取得したaccess_tokenを表示して確認
echo "Access Token: $access_token"

# terraform.tfvarsファイルの存在を確認
if [ -f terraform.tfvars ]; then
    # ファイルが存在する場合、onelogin_access_tokenを更新する
    sed -i '' "s/^onelogin_access_token = .*/onelogin_access_token = \"$access_token\"/" terraform.tfvars
    echo "terraform.tfvarsが更新されました。"
else
    # ファイルが存在しない場合、新規作成する
    echo "onelogin_access_token = \"$access_token\"" > terraform.tfvars
    echo "terraform.tfvarsが新規作成されました。"
fi
