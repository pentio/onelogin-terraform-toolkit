terraform {
  required_providers {
    onelogin = {
      source  = "onelogin/onelogin"
      version = "~> 1.0"
    }
  }
}

# 認証情報は環境変数から読み込まれます（このファイルや .tfvars には書かないでください）。
#   ONELOGIN_CLIENT_ID      API クレデンシャルのクライアント ID
#   ONELOGIN_CLIENT_SECRET  API クレデンシャルのクライアントシークレット
#   ONELOGIN_API_URL        API の URL（https://api.us.onelogin.com または https://api.eu.onelogin.com）
provider "onelogin" {}
