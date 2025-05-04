#!/usr/bin/env python3
"""
Terraformシナリオの実行・停止を管理するCLIツール
既存のrun.shをベースにしたより拡張性のあるバージョンです
"""

import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

import click
import requests
from loguru import logger

# ロガー設定
logger.remove()
logger.add(sys.stderr, level="INFO")

# 利用可能なシナリオ一覧
VALID_SCENARIOS = [
    "metasploitable2",
    "juice_shop",
    "terra_goat",
    "iam_vulnerable",
    "cloudgoat_min",
    "awsgoat_min",
    "all",
]


# カラー定義
class Colors:
    """ANSI カラーコード"""

    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[0;33m"
    NC = "\033[0m"  # No Color


def get_project_root() -> Path:
    """プロジェクトのルートディレクトリを取得"""
    script_dir = Path(__file__).parent.parent.parent.parent
    return script_dir


def run_command(command: List[str], cwd: Optional[Path] = None) -> subprocess.CompletedProcess:
    """コマンドを実行する

    Args:
        command: 実行するコマンドとその引数のリスト
        cwd: 作業ディレクトリ

    Returns:
        実行結果
    """
    logger.debug(f"コマンド実行: {' '.join(command)}")
    return subprocess.run(
        command,
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
    )


def detect_ip() -> Optional[str]:
    """現在のグローバルIPアドレスを検出する

    Returns:
        IPアドレス（検出できない場合はNone）
    """
    try:
        response = requests.get("https://checkip.amazonaws.com", timeout=5)
        ip = response.text.strip()
        return f"{ip}/32"
    except requests.RequestException:
        return None


@click.group()
def cli() -> None:
    """Terraformシナリオの実行・停止を管理するCLIツール"""
    pass


@cli.command("start")
@click.argument("scenario", type=click.Choice(VALID_SCENARIOS))
@click.option("--ip", help="アクセスを許可するIPアドレス (CIDR形式 例: 203.0.113.10/32)")
@click.option("--ttl", default=2, type=int, help="リソースの生存期間（時間）")
def start_scenario(scenario: str, ip: Optional[str], ttl: int) -> None:
    """指定したシナリオを開始します"""
    # IPアドレスの指定がなければ取得を試みる
    if not ip:
        logger.info("IPアドレスが指定されていません。自動検出を試みます...")
        ip = detect_ip()
        if ip:
            logger.info(f"現在のグローバルIPを使用します: {ip}")
        else:
            logger.error(
                "IPアドレスの自動検出に失敗しました。--ipオプションで明示的に指定してください。"
            )
            sys.exit(1)

    # プロジェクトルートに移動
    root_dir = get_project_root()

    try:
        # Terraformの実行
        logger.info(f"シナリオ '{scenario}' を開始（TTL: {ttl}時間）")

        # terraform init
        run_command(["terraform", "init"], cwd=root_dir)

        # terraform plan
        plan_cmd = [
            "terraform",
            "plan",
            f"-var=ttl_hours={ttl}",
            f"-var=my_ip_cidr={ip}",
            f"-var=scenario_name={scenario}",
        ]
        run_command(plan_cmd, cwd=root_dir)

        # terraform apply
        apply_cmd = [
            "terraform",
            "apply",
            "-auto-approve",
            f"-var=ttl_hours={ttl}",
            f"-var=my_ip_cidr={ip}",
            f"-var=scenario_name={scenario}",
        ]
        result = run_command(apply_cmd, cwd=root_dir)

        # 出力を表示
        print(result.stdout)

        logger.info(f"環境が起動しました。{ttl}時間後に自動的に破棄されます")
        logger.info(f"早く終了したい場合は 'bf-run stop {scenario}' を実行してください")

    except subprocess.CalledProcessError as e:
        logger.error(f"コマンド実行中にエラーが発生しました: {e}")
        logger.error(f"エラー出力: {e.stderr}")
        sys.exit(1)


@cli.command("stop")
@click.argument("scenario", type=click.Choice(VALID_SCENARIOS))
def stop_scenario(scenario: str) -> None:
    """指定したシナリオを停止します"""
    # プロジェクトルートに移動
    root_dir = get_project_root()

    try:
        logger.info(f"シナリオ '{scenario}' を停止します...")

        # terraform destroy
        destroy_cmd = ["terraform", "destroy", "-auto-approve", f"-var=scenario_name={scenario}"]
        result = run_command(destroy_cmd, cwd=root_dir)

        # 出力を表示
        print(result.stdout)

        logger.info("環境が正常に破棄されました")

    except subprocess.CalledProcessError as e:
        logger.error(f"コマンド実行中にエラーが発生しました: {e}")
        logger.error(f"エラー出力: {e.stderr}")
        sys.exit(1)


if __name__ == "__main__":
    cli()
