#!/usr/bin/env python3
"""
共通ロガー設定モジュール
"""

import sys
from pathlib import Path
from typing import Optional

from loguru import logger

# デフォルトのログフォーマット
DEFAULT_FORMAT = (
    "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "
    "<level>{level: <8}</level> | "
    "<cyan>{name}</cyan>:<cyan>{line}</cyan> - "
    "<level>{message}</level>"
)


def setup_logger(
    level: str = "INFO",
    log_file: Optional[Path] = None,
    format_str: str = DEFAULT_FORMAT,
) -> None:
    """アプリケーション全体で使用するロガーを設定する

    Args:
        level: ログレベル（DEBUG/INFO/WARNING/ERROR/CRITICAL）
        log_file: ログファイルのパス（指定しない場合は標準エラー出力のみ）
        format_str: ログフォーマット文字列
    """
    # 既存のハンドラをすべて削除
    logger.remove()

    # 標準エラー出力へのハンドラを追加
    logger.add(sys.stderr, level=level, format=format_str)

    # ログファイルへの出力が指定されている場合
    if log_file:
        # ログディレクトリが存在しない場合は作成
        log_file.parent.mkdir(parents=True, exist_ok=True)

        # ログファイルへのハンドラを追加（ローテーション設定付き）
        logger.add(
            log_file,
            level=level,
            format=format_str,
            rotation="5 MB",  # 5MBごとにローテーション
            compression="zip",  # 圧縮形式
            retention=5,  # 5世代まで保持
            enqueue=True,  # スレッドセーフにするため
        )


# 外部からインポート可能なロガーインスタンス
LOGGER = logger
