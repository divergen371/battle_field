▼ 要件をもとにした実装タスク一覧
括弧内は依存関係 →「A → B」は A 完了後に B 着手。優先度は ★3 高 ～ ★1 低。
────────────────────────────────────
リポジトリ初期化 & 基本構成
────────────────────────────────────
★3 1-1. Git リポジトリ初期化・ディレクトリ作成
　　　/modules /scripts /examples /doc を用意
★3 1-2. backend "local" を記述した共通 main.tf 雛形作成
★3 1-3. 入力変数ファイル variables.tf に以下を定義
　　　ttl_hours, my_ip_cidr, scenario_name
★2 1-4. Makefile or scripts/run.sh の枠だけ作成（start/stop サブルール）
────────────────────────────────────
共通ライブラリ／ユーティリティ
────────────────────────────────────
★3 2-1. TTL 自動破棄ロジック
　　　a. null_resource + local-exec（sleep → destroy）
　　　b. EventBridge → Lambda 00:00 実行（どちらか実装）
★2 2-2. SG テンプレート（許可 CIDR だけ変数）
★2 2-3. CloudTrail（マネジメントプレーンのみ）モジュール
★1 2-4. CloudWatch Agent ON/OFF toggle Script（EC2 用）
────────────────────────────────────
シナリオ別モジュール作成
────────────────────────────────────
★3 3-1. metasploitable2 モジュール
　　　– Spot t4g.micro／パブリックIP／ユーザーデータで弱点サービス ON
★3 3-2. juice_shop モジュール
　　　– Fargate Spot Task 0.5vCPU/1GB + HTTP API GW
★2 3-3. terra_goat モジュール（公式テンプレ簡易流用）
★2 3-4. iam_vulnerable モジュール（IAM JSON 模型のみ）
★2 3-5. cloudgoat_min モジュール（EC2 + RDS stopped）
★2 3-6. awsgoat_min モジュール（EC2 + S3 最小）
────────────────────────────────────
スクリプト & UX
────────────────────────────────────
★3 4-1. scripts/run.sh 実装
　　　start: terraform init → plan → apply
　　　stop : terraform destroy（IDempotent 処理）
★2 4-2. scripts/check_cost.sh（AWS CLI で当日使用額を取得）
★1 4-3. scripts/lint.sh：terraform fmt -check / tflint / tfsec
────────────────────────────────────
コスト・セキュリティガード
────────────────────────────────────
★3 5-1. AWS Budgets 10 USD/月, 1 USD/日 作成スクリプト
★2 5-2. SNS Topic + Email/Slack Webhook 通知
★1 5-3. IAM ロール: 演習用最小ポリシーの CloudFormation or Terraform
────────────────────────────────────
ドキュメント & サンプル
────────────────────────────────────
★2 6-1. README.md：前提・使い方・注意点・料金例
★2 6-2. examples/ に metasploitable.auto.tfvars.example 等を配置
★1 6-3. ラボの手順書（doc/labs/）とコスト試算表追記
────────────────────────────────────
動作検証 & リリース
────────────────────────────────────
★3 7-1. 全シナリオで make start → 2h → auto-destroy テスト
★2 7-2. 破棄後に課金対象リソースが残らないことを AWS CLI で確認
★2 7-3. リポジトリ初版タグ付け・公開
これらのタスクを順に実施すれば、要件で定義した「超低コスト・個人学習用脆弱環境」を Terraform で構築・運用できます。
