#!/bin/bash

# エラー発生時に停止
set -e

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 使用方法表示
function usage {
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  $0 start <scenario_name> [--ip <your_ip>/32] [--ttl <hours>]"
    echo -e "  $0 stop <scenario_name>"
    echo -e ""
    echo -e "${YELLOW}Available scenarios:${NC}"
    echo -e "  metasploitable2, juice_shop, terra_goat, iam_vulnerable, cloudgoat_min, awsgoat_min, all"
    echo -e ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 start juice_shop --ip 203.0.113.10/32 --ttl 3"
    echo -e "  $0 stop juice_shop"
    exit 1
}

# 引数チェック
if [ $# -lt 2 ]; then
    usage
fi

ACTION=$1
SCENARIO=$2
IP_CIDR=""
TTL=2

# オプション引数の処理
shift 2
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --ip)
        IP_CIDR="$2"
        shift 2
        ;;
    --ttl)
        TTL="$2"
        shift 2
        ;;
    *)
        echo -e "${RED}Unknown parameter: $1${NC}"
        usage
        ;;
    esac
done

# ディレクトリ設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

# チェック：シナリオの存在確認
valid_scenarios=("metasploitable2" "juice_shop" "terra_goat" "iam_vulnerable" "cloudgoat_min" "awsgoat_min" "all")
valid_scenario=false
for scenario in "${valid_scenarios[@]}"; do
    if [[ "$SCENARIO" == "$scenario" ]]; then
        valid_scenario=true
        break
    fi
done
if [[ "$valid_scenario" == false ]]; then
    echo -e "${RED}Error: Invalid scenario '${SCENARIO}'${NC}"
    usage
fi

# 行動判定
case $ACTION in
start)
    # IPアドレスの指定がなければ取得を試みる
    if [ -z "$IP_CIDR" ]; then
        echo -e "${YELLOW}注意: IPアドレスが指定されていません。自動検出を試みます...${NC}"
        MY_IP=$(curl -s https://checkip.amazonaws.com)
        if [ -n "$MY_IP" ]; then
            IP_CIDR="${MY_IP}/32"
            echo -e "${GREEN}現在のグローバルIPを使用します: ${IP_CIDR}${NC}"
        else
            echo -e "${RED}IPアドレスの自動検出に失敗しました。--ip オプションで明示的に指定してください。${NC}"
            exit 1
        fi
    fi

    # Terraformの実行
    echo -e "${GREEN}シナリオ '${SCENARIO}' を開始（TTL: ${TTL}時間）${NC}"
    terraform init
    terraform plan -var="ttl_hours=${TTL}" -var="my_ip_cidr=${IP_CIDR}" -var="scenario_name=${SCENARIO}"
    terraform apply -auto-approve -var="ttl_hours=${TTL}" -var="my_ip_cidr=${IP_CIDR}" -var="scenario_name=${SCENARIO}"

    echo -e "${GREEN}環境が起動しました。${TTL}時間後に自動的に破棄されます${NC}"
    echo -e "${YELLOW}早く終了したい場合は 'run.sh stop ${SCENARIO}' を実行してください${NC}"
    ;;

stop)
    echo -e "${YELLOW}シナリオ '${SCENARIO}' を停止します...${NC}"
    terraform destroy -auto-approve -var="scenario_name=${SCENARIO}"
    echo -e "${GREEN}環境が正常に破棄されました${NC}"
    ;;

*)
    echo -e "${RED}不明なアクション: ${ACTION}${NC}"
    usage
    ;;
esac
