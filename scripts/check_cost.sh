#!/bin/bash

# エラー発生時に停止
set -e

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}AWS Cost Explorer APIを使用して現在の使用コストを取得しています...${NC}"

# 現在の年月
YEAR_MONTH=$(date +"%Y-%m")
# 現在の日
TODAY=$(date +"%Y-%m-%d")
# 月初め
MONTH_START="${YEAR_MONTH}-01"

# コストを取得（サービス別）
echo -e "${YELLOW}今月のサービス別コスト:${NC}"
aws ce get-cost-and-usage \
    --time-period Start=${MONTH_START},End=${TODAY} \
    --granularity MONTHLY \
    --metrics "UnblendedCost" \
    --group-by Type=DIMENSION,Key=SERVICE \
    | jq -r '.ResultsByTime[0].Groups[] | "\(.Keys[0]): \(.Metrics.UnblendedCost.Amount) \(.Metrics.UnblendedCost.Unit)"' \
    | sort -k2 -nr \
    | head -10

# 本日のコスト
echo -e "\n${YELLOW}今日のコスト:${NC}"
aws ce get-cost-and-usage \
    --time-period Start=${TODAY},End=$(date -d "tomorrow" +"%Y-%m-%d") \
    --granularity DAILY \
    --metrics "UnblendedCost" \
    | jq -r '.ResultsByTime[0].Total.UnblendedCost | "合計: \(.Amount) \(.Unit)"'

# 今月のコスト
echo -e "\n${YELLOW}今月のコスト合計:${NC}"
aws ce get-cost-and-usage \
    --time-period Start=${MONTH_START},End=$(date -d "tomorrow" +"%Y-%m-%d") \
    --granularity MONTHLY \
    --metrics "UnblendedCost" \
    | jq -r '.ResultsByTime[0].Total.UnblendedCost | "合計: \(.Amount) \(.Unit)"'

echo -e "\n${YELLOW}注意: AWS Cost Explorerのデータは通常12-24時間遅れて反映されます${NC}"
echo -e "${YELLOW}最新の使用状況は含まれていない可能性があります${NC}"
echo -e "${GREEN}最新かつ詳細なコスト情報はAWSコンソールの「Billing & Cost Management」で確認できます${NC}" 