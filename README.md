# OneLogin Terraform 設定

このリポジトリには、OneLoginリソースを管理するためのTerraform設定ファイルとユーティリティスクリプトが含まれています。

## ディレクトリ構造

```
onelogin-terraform/
├── provider.tf
├── variables.tf
├── import_onelogin_rules.sh
├── licence_generator.sh
├── onelogin_api_generate_access-token.sh
```

## Terraform設定ファイル

### `variables.tf`

OneLoginのAPIキーを格納する変数を定義します：

```hcl
variable "onelogin_access_token" {
  description = "OneLoginのAPIキー"
  type        = string
}
```

### `provider.tf`

OneLoginプロバイダーを設定します：

```hcl
terraform {
  required_providers {
    onelogin = {
      source  = "onelogin/onelogin"
      version = "0.4.9"
    }
  }
}

provider "onelogin" {
  apikey_auth = var.onelogin_access_token
}
```

注意：プロバイダーのバージョンは定期的に更新されます。最新のバージョンは[Terraform Registry](https://registry.terraform.io/providers/onelogin/onelogin/latest)で確認できます。プロバイダーを更新する場合は、`provider.tf`ファイル内の`version`値を変更し、`terraform init -upgrade`を実行してください。

## ユーティリティスクリプト

### `import_onelogin_rules.sh`

OneLoginアプリケーションルールをTerraformにインポートするスクリプトです。

使用方法：
```bash
./import_onelogin_rules.sh <app_id> <output_file>
```

- `<app_id>`: OneLoginアプリケーションID
- `<output_file>`: 出力するTerraformファイル名

このスクリプトは以下の処理を行います：
1. OneLogin APIからアプリケーションルールを取得
2. 取得したルールをTerraformリソースとしてインポート
3. インポートしたリソースを指定された出力ファイルに書き込み

注意：
- このスクリプトを実行する前に、`terraform.tfvars`ファイルにOneLoginのアクセストークンが設定されていることを確認してください。
- Terraformがインストールされ、初期化されていることを確認してください。

### `licence_generator.sh`

CSV形式の製品ライセンス情報からTerraform用のアクションを生成するスクリプトです。

使用方法：
```bash
./licence_generator.sh
```

このスクリプトは以下の処理を行います：
1. `product_licenses.csv`ファイルから製品ライセンス情報を読み込み
2. 製品ごとにライセンスアクションを生成
3. 生成したアクションを`product_actions.txt`ファイルに出力

注意：
- 入力ファイル名（`product_licenses.csv`）と出力ファイル名（`product_actions.txt`）はスクリプト内で定義されています。必要に応じて変更してください。
- スクリプトを実行する前に、Python3がインストールされていることを確認してください。
- CSVファイルは[Microsoft Entra ID のライセンスとサービス プランの一覧](https://learn.microsoft.com/ja-jp/entra/identity/users/licensing-service-plan-reference)からダウンロードできます。このページから最新の製品ライセンス情報を取得し、`product_licenses.csv`として保存してください。

### `onelogin_api_generate_access-token.sh`

OneLogin API用のアクセストークンを生成するスクリプトです。

使用方法：
```bash
./onelogin_api_generate_access-token.sh
```

このスクリプトは以下の処理を行います：
1. `.env`ファイルから環境変数を読み込み
2. OneLogin APIにアクセストークンをリクエスト
3. 取得したアクセストークンを表示
4. `terraform.tfvars`ファイルにアクセストークンを書き込み

注意：
- このスクリプトを実行する前に、`.env`ファイルに以下の変数が設定されていることを確認してください：
  - `CLIENT_ID`: OneLoginのクライアントID
  - `CLIENT_SECRET`: OneLoginのクライアントシークレット
  - `SUBDOMAIN`: OneLoginのサブドメイン
- `jq`コマンドがインストールされていることを確認してください。

## セキュリティに関する注意

- `onelogin_access_token`は機密情報です。安全に保管し、バージョン管理システムにコミットしないようにしてください。
- `.env`ファイルや`terraform.tfvars`ファイルも機密情報を含むため、バージョン管理システムから除外してください。

## 更新とメンテナンス

- プロバイダーのバージョン：定期的に[Terraform Registry](https://registry.terraform.io/providers/onelogin/onelogin/latest)で最新バージョンを確認し、`provider.tf`ファイルを更新してください。
- ライセンス情報：[Microsoft Entra ID のライセンスとサービス プランの一覧](https://learn.microsoft.com/ja-jp/entra/identity/users/licensing-service-plan-reference)から最新のCSVファイルをダウンロードし、`product_licenses.csv`を更新してください。
