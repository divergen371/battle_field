#!/usr/bin/env python3
"""
AWS予算とアラートを設定するスクリプト
既存のsetup_budgets.pyをベースにしたより拡張性のあるバージョンです
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import boto3
import click
from loguru import logger

# ロガー設定
logger.remove()
logger.add(sys.stderr, level="INFO")


def create_budget(
    name: str,
    limit_amount: float,
    time_unit: str,
    email: str,
    account_id: Optional[str] = None,
) -> Dict[str, Any]:
    """AWSの予算とアラームを作成する

    Args:
        name: 予算名
        limit_amount: 上限金額（USD）
        time_unit: 時間単位（DAILY/MONTHLY）
        email: 通知先メールアドレス
        account_id: AWSアカウントID（指定しない場合は現在のアカウント）

    Returns:
        作成した予算の情報
    """
    client = boto3.client("budgets")

    if not account_id:
        account_id = boto3.client("sts").get_caller_identity().get("Account")

    # 予算とアラートの作成
    response = client.create_budget(
        AccountId=account_id,
        Budget={
            "BudgetName": name,
            "BudgetLimit": {"Amount": str(limit_amount), "Unit": "USD"},
            "TimeUnit": time_unit,
            "BudgetType": "COST",
            "CostTypes": {
                "IncludeTax": True,
                "IncludeSubscription": True,
                "UseBlended": False,
                "IncludeRefund": False,
                "IncludeCredit": False,
                "IncludeUpfront": True,
                "IncludeRecurring": True,
                "IncludeOtherSubscription": True,
                "IncludeSupport": True,
                "IncludeDiscount": True,
                "UseAmortized": False,
            },
        },
        NotificationsWithSubscribers=[
            {
                "Notification": {
                    "NotificationType": "ACTUAL",
                    "ComparisonOperator": "GREATER_THAN",
                    "Threshold": 80.0,
                    "ThresholdType": "PERCENTAGE",
                    "NotificationState": "ALARM",
                },
                "Subscribers": [{"SubscriptionType": "EMAIL", "Address": email}],
            },
            {
                "Notification": {
                    "NotificationType": "ACTUAL",
                    "ComparisonOperator": "GREATER_THAN",
                    "Threshold": 100.0,
                    "ThresholdType": "PERCENTAGE",
                    "NotificationState": "ALARM",
                },
                "Subscribers": [{"SubscriptionType": "EMAIL", "Address": email}],
            },
        ],
    )
    return response


@click.group()
def cli() -> None:
    """AWS予算アラート設定ツール"""
    pass


@cli.command("setup")
@click.option("--email", required=True, help="通知先のメールアドレス")
@click.option("--monthly-limit", default=10.0, type=float, help="月次予算の上限（USD）")
@click.option("--daily-limit", default=1.0, type=float, help="日次予算の上限（USD）")
def setup_budgets(email: str, monthly_limit: float, daily_limit: float) -> None:
    """予算アラートを設定します"""
    logger.info("AWS予算設定スクリプト - ペネトレーションテスト環境")

    try:
        # 月次予算
        monthly_name = f"pentest-lab-monthly-budget-{datetime.now().strftime('%Y%m')}"
        monthly_response = create_budget(
            name=monthly_name, limit_amount=monthly_limit, time_unit="MONTHLY", email=email
        )

        # 日次予算
        daily_name = f"pentest-lab-daily-budget-{datetime.now().strftime('%Y%m%d')}"
        daily_response = create_budget(
            name=daily_name, limit_amount=daily_limit, time_unit="DAILY", email=email
        )

        logger.success(
            f"月次予算（{monthly_limit} USD）を作成しました: {monthly_response['BudgetName']}"
        )
        logger.success(
            f"日次予算（{daily_limit} USD）を作成しました: {daily_response['BudgetName']}"
        )
        logger.info(f"予算超過時は {email} に通知されます")
        logger.info("注意: 予算アラームの反映には数時間かかる場合があります")

    except Exception as e:
        logger.error(f"エラーが発生しました: {str(e)}")
        logger.error("必要なIAM権限: budgets:CreateBudget, sts:GetCallerIdentity")
        sys.exit(1)


@cli.command("list")
def list_budgets() -> None:
    """設定されている予算一覧を表示します"""
    client = boto3.client("budgets")
    account_id = boto3.client("sts").get_caller_identity().get("Account")

    try:
        response = client.describe_budgets(AccountId=account_id)

        if not response["Budgets"]:
            logger.info("予算が設定されていません")
            return

        logger.info(f"予算一覧（合計: {len(response['Budgets'])}件）:")
        for budget in response["Budgets"]:
            logger.info(
                f"- {budget['BudgetName']}: {budget['BudgetLimit']['Amount']} {budget['BudgetLimit']['Unit']} ({budget['TimeUnit']})"
            )

    except Exception as e:
        logger.error(f"エラーが発生しました: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    cli()
