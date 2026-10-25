#!/bin/bash
# import_onelogin_rules.sh がルール1件から作る HCL（jq のプログラム）の単体テスト。認証情報は不要。
#   tests/generate_hcl_test.sh [生成した HCL の出力先]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$(mktemp)}"

# スクリプトから jq のプログラムを取り出す（RULE_TO_HCL='...' の部分）
PROG=$(awk "/^RULE_TO_HCL='/{f=1;next} f&&/^'\$/{f=0} f" "$ROOT/import_onelogin_rules.sh")
[ -n "$PROG" ] || { echo "Error: import_onelogin_rules.sh から RULE_TO_HCL を取り出せません。"; exit 1; }

jq -r --arg app 123456 "$PROG" "$ROOT/tests/fixtures/rule.json" > "$OUT"

fail=0
check() { grep -qF -- "$1" "$OUT" || { echo "NG: 生成結果に見つかりません: $1"; fail=1; }; }
check 'resource "onelogin_app_rules" "rule_12345"'
check 'app_id   = "123456"'
check 'name     = "規則 \"A\" \\ $${x} %%{y}"'   # 引用符・バックスラッシュ・${ ・%{ がエスケープされる
check 'expression = ".*"'
check 'macro = "{firstname}"'
check 'value  = ["a:b","c:d"]'
check 'value  = []'                              # value が null のアクションも、必須の value を省略しない
check 'value    = "570882"'                      # 数値の条件値は文字列にする
[ "$(grep -c '^  actions {' "$OUT")" -eq 3 ] || { echo "NG: actions が 3 件ではありません"; fail=1; }
[ "$(grep -c '^  conditions {' "$OUT")" -eq 2 ] || { echo "NG: conditions が 2 件ではありません"; fail=1; }
[ "$fail" -eq 0 ] && echo "OK: ルール生成の単体テスト"
exit $fail
