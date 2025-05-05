# Battle Field スクリプト

AWS Pentest Lab Terraformスクリプトの実行・管理ツール

## 概要

このパッケージは、Battle FieldプロジェクトのためのPythonスクリプト群を提供します。
Terraformスクリプトの実行、AWSコスト確認、バジェット設定などの機能があります。

## インストール方法

**uvを使用した環境構築：**

```bash
# 仮想環境を作成
uv venv .venv

# 開発環境のセットアップ
uv pip install -e .
```

## 利用可能なコマンド

インストール後、以下のコマンドが使用可能になります：

- `bf-run` - Terraformシナリオの実行・停止を管理
- `bf-cost` - AWS使用コストを確認
- `bf-budget` - AWS予算アラートを設定

## 必要なIAM権限

このツールを使用するには、AWSユーザーに以下の権限が必要です：

### コスト確認 (`bf-cost`)

```json
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
```

### 予算設定 (`bf-budget`)

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "budgets:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## ディレクトリ構成

```
scripts/python/
  ├── aws/       - AWS関連ユーティリティ
  ├── cli/       - コマンドラインインターフェース 
  └── utils/     - 共通ユーティリティ
```

## 開発

開発には以下のツールを使用しています：

- ruff - リンターとフォーマッター
- mypy - 静的型チェック
- pytest - テストフレームワーク

コード品質チェックを実行するには：

```bash
# 型チェック
mypy .

# リントとフォーマット
ruff check .
ruff format .

# テスト実行
pytest
``` 