#!/usr/bin/env python3
"""
AWS Cost Explorer APIを使用してコストを取得するスクリプト
既存のcheck_cost.shをベースにしたより拡張性のあるバージョンです

注意: このスクリプトを使用するには、以下のIAMポリシーがユーザーに必要です:
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ce:GetCostAndUsage"
            ],
            "Resource": "*"
        }
    ]
}
"""

import sys
import traceback
from datetime import datetime, timedelta
from typing import Any, Dict, List

import boto3  # type: ignore
import botocore.exceptions  # type: ignore
import click
from loguru import logger
from rich.console import Console
from rich.table import Table

# ロガー設定
logger.remove()
logger.add(sys.stderr, level="INFO")

# リッチコンソール
console = Console()


def get_service_costs(
    start_date: str, end_date: str, granularity: str = "MONTHLY"
) -> List[Dict[str, Any]]:
    """サービス別のコストを取得する

    Args:
        start_date: 開始日（YYYY-MM-DD形式）
        end_date: 終了日（YYYY-MM-DD形式）
        granularity: 粒度（DAILY/MONTHLY）

    Returns:
        サービス別のコスト情報のリスト
    """
    client = boto3.client("ce")

    response = client.get_cost_and_usage(
        TimePeriod={"Start": start_date, "End": end_date},
        Granularity=granularity,
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )

    result = []
    if response["ResultsByTime"]:
        for group in response["ResultsByTime"][0]["Groups"]:
            service = group["Keys"][0]
            amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
            unit = group["Metrics"]["UnblendedCost"]["Unit"]
            result.append({"service": service, "amount": amount, "unit": unit})

    # コスト降順でソート
    result.sort(key=lambda x: x["amount"], reverse=True)
    return result


def get_total_cost(
    start_date: str, end_date: str, granularity: str = "MONTHLY"
) -> Dict[str, Any]:
    """期間の合計コストを取得する

    Args:
        start_date: 開始日（YYYY-MM-DD形式）
        end_date: 終了日（YYYY-MM-DD形式）
        granularity: 粒度（DAILY/MONTHLY）

    Returns:
        合計コスト情報
    """
    client = boto3.client("ce")

    response = client.get_cost_and_usage(
        TimePeriod={"Start": start_date, "End": end_date},
        Granularity=granularity,
        Metrics=["UnblendedCost"],
    )

    if response["ResultsByTime"]:
        amount = float(
            response["ResultsByTime"][0]["Total"]["UnblendedCost"]["Amount"]
        )
        unit = response["ResultsByTime"][0]["Total"]["UnblendedCost"]["Unit"]
        return {"amount": amount, "unit": unit}

    return {"amount": 0.0, "unit": "USD"}


@click.group()
def cli() -> None:
    """AWSコスト確認ツール"""
    pass


@cli.command("today")
def show_today_cost() -> None:
    """今日のコストを表示します"""
    today = datetime.now().strftime("%Y-%m-%d")
    tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")

    try:
        # 今日のコスト
        daily_cost = get_total_cost(today, tomorrow, "DAILY")

        console.print("[bold cyan]今日のコスト:[/bold cyan]")
        console.print(f"合計: {daily_cost['amount']:.2f} {daily_cost['unit']}")

        console.print(
            "\n[bold yellow]注意: AWS Cost Explorerのデータは通常12-24時間遅れて"
            "反映されます[/bold yellow]"
        )
        console.print("[yellow]最新の使用状況は含まれていない可能性があります[/yellow]")

    except botocore.exceptions.ClientError as e:
        error_code = e.response.get("Error", {}).get("Code", "Unknown")
        error_message = e.response.get("Error", {}).get("Message", str(e))
        logger.error(f"AWS APIエラー: {error_code} - {error_message}")
        logger.error("必要なIAM権限: ce:GetCostAndUsage")
        logger.debug(f"詳細なエラー情報: {e}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"予期せぬエラーが発生しました: {str(e)}")
        logger.debug(traceback.format_exc())
        sys.exit(1)


@cli.command("month")
def show_month_cost() -> None:
    """今月のコストを表示します"""
    # 月初め
    today = datetime.now()
    month_start = f"{today.year}-{today.month:02d}-01"
    tomorrow = (today + timedelta(days=1)).strftime("%Y-%m-%d")

    try:
        # サービス別コスト
        services = get_service_costs(month_start, tomorrow)

        # 今月の合計コスト
        monthly_cost = get_total_cost(month_start, tomorrow)

        # テーブル表示
        table = Table(title="今月のサービス別コスト")
        table.add_column("サービス", style="cyan")
        table.add_column("コスト", justify="right", style="green")
        table.add_column("通貨", style="dim")

        for service in services[:10]:  # トップ10のみ表示
            table.add_row(
                service["service"],
                f"{service['amount']:.4f}",
                service["unit"],
            )

        console.print(table)
        console.print(
            f"\n[bold cyan]今月のコスト合計:[/bold cyan] "
            f"{monthly_cost['amount']:.2f} {monthly_cost['unit']}"
        )

        console.print(
            "\n[bold yellow]注意: AWS Cost Explorerのデータは通常12-24時間遅れて"
            "反映されます[/bold yellow]"
        )
        console.print("[yellow]最新の使用状況は含まれていない可能性があります[/yellow]")
        console.print(
            "[green]最新かつ詳細なコスト情報はAWSコンソールの"
            "「Billing & Cost Management」で確認できます[/green]"
        )

    except botocore.exceptions.ClientError as e:
        error_code = e.response.get("Error", {}).get("Code", "Unknown")
        error_message = e.response.get("Error", {}).get("Message", str(e))
        logger.error(f"AWS APIエラー: {error_code} - {error_message}")
        logger.error("必要なIAM権限: ce:GetCostAndUsage")
        logger.debug(f"詳細なエラー情報: {e}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"予期せぬエラーが発生しました: {str(e)}")
        logger.debug(traceback.format_exc())
        sys.exit(1)


if __name__ == "__main__":
    cli()
