#!/bin/bash
#
# Lambda関数のデプロイパッケージを作成するスクリプト
#

set -e

SCRIPT_DIR=$(dirname "$0")
LAMBDA_DIR="${SCRIPT_DIR}/lambda_function"
OUTPUT_ZIP="${SCRIPT_DIR}/lambda_function.zip"

echo "Lambda関数のデプロイパッケージを作成します..."

# 既存のZIPファイルがあれば削除
if [ -f "${OUTPUT_ZIP}" ]; then
  rm "${OUTPUT_ZIP}"
  echo "既存のZIPファイルを削除しました"
fi

# Lambda関数ディレクトリが存在するか確認
if [ ! -d "${LAMBDA_DIR}" ]; then
  echo "エラー: Lambda関数ディレクトリが見つかりません: ${LAMBDA_DIR}"
  exit 1
fi

# ZIPファイルを作成
cd "${LAMBDA_DIR}"
zip -r "${OUTPUT_ZIP}" .
cd - > /dev/null

echo "Lambda関数のデプロイパッケージを作成しました: ${OUTPUT_ZIP}" 