#!/bin/bash
# 実際の OneLogin テナント（検証用）に対する動作テスト。
#
#   1. 作業ディレクトリ A で、テスト用のロール・SAML アプリ・アプリルール（記号を含む名前、expression、macro つき）を作成
#   2. 別の作業ディレクトリ B で import_onelogin_rules.sh を実行して、ルールをインポートし、定義を生成
#   3. B で terraform plan を実行し、生成した定義と OneLogin の状態に差分が無い（終了コード 0）ことを確認
#   4. 必ず（失敗しても）A のリソースを destroy して後片付けする
#
# 必要な環境変数: ONELOGIN_CLIENT_ID / ONELOGIN_CLIENT_SECRET / ONELOGIN_API_URL
# テスト用のリソースの名前は ci-<実行ID> で始まる。**検証用のテナントでだけ実行すること**（本番のテナントでは実行しない）。
set -euo pipefail

for v in ONELOGIN_CLIENT_ID ONELOGIN_CLIENT_SECRET ONELOGIN_API_URL; do
    [ -n "${!v:-}" ] || { echo "Error: 環境変数 $v が設定されていません。"; exit 1; }
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_ID="${GITHUB_RUN_ID:-local$(date +%s)}"
PREFIX="ci-${RUN_ID}"
WORK="$(mktemp -d)"
A="$WORK/a"; B="$WORK/b"
mkdir -p "$A" "$B"

cleanup() {
    status=$?
    echo "== 後片付け（destroy）"
    if [ -f "$A/terraform.tfstate" ]; then
        (cd "$A" && terraform destroy -auto-approve -input=false -no-color) || {
            echo "!! destroy に失敗しました。テナントに '${PREFIX}' で始まるリソースが残っている可能性があります。"; status=1; }
    fi
    rm -rf "$WORK"
    exit $status
}
trap cleanup EXIT

cp "$ROOT/providers.tf" "$A/"
cat > "$A/main.tf" <<'TF'
resource "onelogin_roles" "r" {
  name = "__PREFIX__-role"
}

resource "onelogin_saml_apps" "app" {
  connector_id = 50534
  name         = "__PREFIX__-app"
  description  = "toolkit e2e test"
  configuration = {
    signature_algorithm = "SHA-256"
  }
}

# 記号を含む名前、expression、macro を含むルール
resource "onelogin_app_rules" "first" {
  app_id  = onelogin_saml_apps.app.id
  enabled = true
  match   = "all"
  name    = "__PREFIX__ rule \"quoted\" \\ $${not_interpolated}"
  conditions {
    operator = "ri"
    source   = "has_role"
    value    = onelogin_roles.r.id
  }
  actions {
    action     = "set_amazonusername"
    expression = ".*"
    value      = ["member_of"]
  }
}

resource "onelogin_app_rules" "second" {
  app_id     = onelogin_saml_apps.app.id
  depends_on = [onelogin_app_rules.first]
  enabled    = false
  match      = "any"
  name       = "__PREFIX__ second"
  conditions {
    operator = "ri"
    source   = "has_role"
    value    = onelogin_roles.r.id
  }
  actions {
    action = "set_amazonusername"
    macro  = "{firstname}.{lastname}"
  }
}

output "app_id" {
  value = onelogin_saml_apps.app.id
}
TF
sed -i.bak "s/__PREFIX__/${PREFIX}/g" "$A/main.tf" && rm -f "$A/main.tf.bak"

echo "== 1. テスト用リソースの作成"
(cd "$A" && terraform init -input=false -no-color >/dev/null && terraform apply -auto-approve -input=false -no-color)
APP_ID=$(cd "$A" && terraform output -raw app_id)

echo "== 2. import_onelogin_rules.sh でインポート（アプリ ID: $APP_ID）"
cp "$ROOT/providers.tf" "$ROOT/import_onelogin_rules.sh" "$B/"
chmod +x "$B/import_onelogin_rules.sh"
(cd "$B" && ./import_onelogin_rules.sh "$APP_ID" rules.tf)
grep -c '^resource "onelogin_app_rules"' "$B/rules.tf" | grep -qx 2 || { echo "Error: 生成された rules.tf のルールが 2 件ではありません。"; cat "$B/rules.tf"; exit 1; }

echo "== 3. 生成した定義と OneLogin の状態に差分が無いこと"
set +e
(cd "$B" && terraform plan -detailed-exitcode -input=false -no-color)
code=$?
set -e
if [ "$code" -ne 0 ]; then
    echo "Error: terraform plan に差分があります（終了コード $code）。生成された定義:"
    cat "$B/rules.tf"
    exit 1
fi
echo "OK: 差分なし"
