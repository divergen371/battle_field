# AWS 超低コスト脆弱性環境 Terraform

AWSで様々な脆弱性テスト環境を低コスト（月5 USD以内）で構築するためのTerraformプロジェクトです。個人学習や脆弱性検証に最適です。

## 概要

- **コスト最適化**: 利用時のみ環境を起動し、使わないときは完全に削除
- **TTL自動破棄**: 指定時間後に自動的にリソースを削除するため、課金の心配なし
- **複数シナリオ**: Metasploitable2、OWASP Juice Shop、TerraGoat、iam-vulnerable等
- **IP制限**: 自分のIPアドレスからのみアクセス可能で安全に隔離
- **最小権限**: コスト効率の良いt4g.micro（Spot）を使用、必要なリソースのみ作成

## 前提条件

- AWS CLIがインストール済みで、適切なIAM権限を持つAWSアカウント設定済み
- Terraform 1.0以上がインストール済み
- AWS上に脆弱性環境を作成する責任と知識

## 使い方

### 1. リポジトリのクローンとセットアップ

```bash
git clone https://github.com/divergen371/battle_field.git
cd battle_field
```

### 2. 変数ファイルの設定

`examples` ディレクトリにあるサンプルファイルを使用します：

```bash
cp examples/metasploitable2.auto.tfvars.example metasploitable2.auto.tfvars
```

ファイルを編集して自分のIPアドレスを設定します（必ず実施）：

```text
my_ip_cidr = "あなたのIP/32"  # 例: "203.0.113.10/32"
```

### 3. 実行と停止

実行方法（2つのオプションがあります）：

**A. シェルスクリプト経由（推奨）**:

```bash
# Metasploitable2の起動
./scripts/run.sh start metasploitable2 --ip あなたのIP/32 --ttl 2

# 環境の停止（2時間後に自動停止しますが、手動でも可能）
./scripts/run.sh stop metasploitable2
```

**B. Terraform直接実行**:

```bash
# 初期化
terraform init

# プラン確認
terraform plan -var-file=metasploitable2.auto.tfvars

# デプロイ
terraform apply -var-file=metasploitable2.auto.tfvars

# 削除
terraform destroy -var-file=metasploitable2.auto.tfvars
```

### 4. 自動TTL

設定した時間（デフォルト2時間）後に、環境は自動的に削除されます。これにより料金の発生を防ぎます。

## 利用可能なシナリオ

| シナリオ名 | 説明 | 推定コスト（2時間） |
|------------|------|-------------------|
| metasploitable2 | 古典的な脆弱なLinux環境（SSH/FTP/HTTP等各種脆弱サービス） | 約$0.01 |
| juice_shop | OWASPのモダンなWeb脆弱性テスト環境 | 約$0.02 |
| terra_goat | IaC脆弱性テスト環境 | 約$0.00 |
| iam_vulnerable | AWS IAM脆弱性検証環境 | 約$0.00 |
| cloudgoat_min | CloudGoat最小版 | 約$0.02 |
| awsgoat_min | AWSGoat最小版 | 約$0.01 |

※ 毎月4回使用しても合計$1未満の使用量に抑えられます。

## 注意事項

- 必ず信頼できるネットワークから、正当な目的のみに使用してください
- 常時起動ではなく、必要時だけ起動することを強く推奨します
- AWS Budget設定で毎月の上限金額を設定することも検討してください
- 本番環境のAWSアカウントとは別のアカウントでの使用を推奨します

## ライセンス

MITライセンス（詳細はLICENSEファイルを参照）
