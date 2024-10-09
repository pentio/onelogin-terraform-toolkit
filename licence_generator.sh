#!/bin/bash

INPUT_FILE="product_licenses.csv"
OUTPUT_FILE="product_actions.txt"

# 出力ファイルを初期化
> "$OUTPUT_FILE"

# CSVファイルを処理し、製品名ごとにアクションを生成
python3 << END
import csv
import sys
from collections import defaultdict

input_file = '$INPUT_FILE'
output_file = '$OUTPUT_FILE'

try:
    products = defaultdict(lambda: defaultdict(set))

    with open(input_file, 'r', newline='', encoding='utf-8-sig') as csvfile:
        reader = csv.reader(csvfile)
        next(reader)  # ヘッダーをスキップ
        for row in reader:
            if len(row) >= 6:
                product_name = row[0]
                guid = row[2]
                service_plan_id = row[4]
                friendly_names = row[5]
                products[product_name][f"{guid}:{service_plan_id}"].add(friendly_names)

    with open(output_file, 'w', encoding='utf-8') as outfile:
        for product_name, guids in products.items():
            outfile.write(f"{product_name}\n")
            outfile.write("  actions {\n")
            outfile.write('    action = "set_licenses"\n')
            outfile.write("    value  = [\n")
            for guid, friendly_names in sorted(guids.items()):
                friendly_names_str = ", ".join(sorted(friendly_names))
                outfile.write(f'      "{guid}",  # {friendly_names_str}\n')
            outfile.write("    ]\n")
            outfile.write("  }\n\n")

    print(f"処理が完了しました。結果は {output_file} に出力されました。")
except Exception as e:
    print(f"エラーが発生しました: {e}", file=sys.stderr)
    sys.exit(1)
END

# Pythonスクリプトの終了ステータスをチェック
if [ $? -eq 0 ]; then
    echo "スクリプトの実行が正常に完了しました。"
else
    echo "スクリプトの実行中にエラーが発生しました。"
    exit 1
fi
