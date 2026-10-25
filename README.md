# OneLogin Terraform 設定

このリポジトリには、OneLoginリソースを管理するためのTerraform設定ファイルとユーティリティスクリプトが含まれています。

## ディレクトリ構造

```
onelogin-terraform-toolkit/
├── providers.tf
├── import_onelogin_rules.sh
├── licence_generator.sh
├── .gitignore
```

## Terraform設定ファイル

### `providers.tf`

OneLoginプロバイダーを設定します（v1.x）：

```hcl
terraform {
  required_providers {
    onelogin = {
      source  = "onelogin/onelogin"
      version = "~> 1.0"
    }
  }
}

provider "onelogin" {}
```

認証情報はファイルに書かず、環境変数で渡します：

```bash
export ONELOGIN_CLIENT_ID=<クライアントID>
export ONELOGIN_CLIENT_SECRET=<クライアントシークレット>
export ONELOGIN_API_URL=https://api.us.onelogin.com   # EU の場合は https://api.eu.onelogin.com
```

注意：
- プロバイダーは、これらの認証情報からアクセストークンを自分で取得します。アクセストークンを変数やファイルで渡す必要はありません（v0.4.x まで使えた `apikey_auth` は、v0.5.0 で廃止されています）。
- 以前の設定（`.env` の `CLIENT_ID`／`CLIENT_SECRET`／`SUBDOMAIN` や、`terraform.tfvars` のアクセストークン）からの移行：これらはもう読み込まれません。上の環境変数（`ONELOGIN_CLIENT_ID`、`ONELOGIN_CLIENT_SECRET`、`ONELOGIN_API_URL`）に置き換え、`terraform.tfvars` のトークンは削除してください。
- `version = "~> 1.0"` は、`terraform init` のたびに最新の 1.x を選びます。1.x の中でも plan の挙動が変わる変更があるため、動作を固定したいときは、`terraform init` で作られる `.terraform.lock.hcl` をリポジトリに含めて共有するか、確認したバージョンを指定してください（例：`version = "1.11.0"`）。
- 設定できる項目と各リソースの書き方は、[Terraform Registry](https://registry.terraform.io/providers/onelogin/onelogin/latest/docs) と[プロバイダーのリポジトリ](https://github.com/onelogin/terraform-provider-onelogin)（`docs/`、`examples/`）を参照してください。
- 以前のバージョンから更新する場合は、先に[リリースノート](https://github.com/onelogin/terraform-provider-onelogin/releases)の破壊的変更（v1.0.0 ほか）を確認し、`terraform plan` の差分を確認してから適用してください。

## ユーティリティスクリプト

### `import_onelogin_rules.sh`

OneLoginアプリケーションルールを読み出し、Terraformにインポートして、`onelogin_app_rules` リソースの定義を出力するスクリプトです。

使用方法：
```bash
./import_onelogin_rules.sh <app_id> <output_file>
```

- `<app_id>`: OneLoginアプリケーションID
- `<output_file>`: 出力するTerraformファイル名

このスクリプトは以下の処理を行います：
1. 環境変数の認証情報でアクセストークンを取得（表示・保存はしません）
2. OneLogin APIからアプリケーションルールを取得
3. ルールごとに `terraform import onelogin_app_rules.rule_<ルールID> <app_id>/<ルールID>` を実行
4. インポートできたルールのリソース定義を指定された出力ファイルに書き込み（`actions` の `expression`・`macro`・`scriptlet` も含みます。文字列は HCL として正しくなるようにエスケープします）

注意：
- 実行前に、上記の環境変数（`ONELOGIN_CLIENT_ID`、`ONELOGIN_CLIENT_SECRET`、`ONELOGIN_API_URL`）を設定してください。
- Terraform（初期化済みであること）、`curl`、`jq` が必要です。

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

## セキュリティに関する注意

- クライアントシークレットは機密情報です。安全に保管し、バージョン管理システムにコミットしないでください。
- `.env` や `*.tfvars`、Terraform の state ファイルも機密情報を含み得ます。このリポジトリの `.gitignore` で除外していますが、別の場所に置く場合も同様に扱ってください。

## 更新とメンテナンス

- プロバイダーのバージョン：定期的に [Terraform Registry](https://registry.terraform.io/providers/onelogin/onelogin/latest) で最新バージョンを確認し、`providers.tf` の `version` を更新して `terraform init -upgrade` を実行してください。
- ライセンス情報：[Microsoft Entra ID のライセンスとサービス プランの一覧](https://learn.microsoft.com/ja-jp/entra/identity/users/licensing-service-plan-reference)から最新のCSVファイルをダウンロードし、`product_licenses.csv` を更新してください。
