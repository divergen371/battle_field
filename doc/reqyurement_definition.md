# 個人学習向け・超低コスト脆弱環境（AWS＋Terraform）要件一覧

（月額 5 USD 以内・"使う時だけ起動／終わったら完全破棄" 方針）

────────────────────────────────────

## 1. 機能要件

────────────────────────────────────

- F-1　Terraform コマンド 2つだけで各シナリオを開始／終了できる
  - 例make start SCENARIO=juice_shop`、`make stop SCENARIO=juice_shop`
- F-2　対応シナリオ：Metasploitable2、OWASP Juice
   Shop、TerraGoat、iam-vulnerable、CloudGoat(最小のみ)、AWSGoat(最小のみ)
- F-3　演習 1 回あたり 2 時間以内で完結し、終了後は AWS内に課金対象リソースが残らない
- F-4　利用者の固定グローバル IP（または自宅 CIDR）のみ Security Group で許可
- F-5　デプロイ完了まで 10 分以内、destroy は 5 分以内

────────────────────────────────────

## 2. 非機能要件（コスト最適化特化）

────────────────────────────────────

- N-1　"常時稼働" リソースをゼロにする
  - NAT Gateway／踏み台 EC2／GuardDuty／Config／ALB は原則作らない
- N-2　演習インスタンスは Spot（または無料枠 t4g.micro）を利用
- N-3　EBS は `DeleteOnTermination=false`＋スナップショット圧縮で長期保存
- N-4　Terraform backend は `local`、State はローカル暗号化（S3 不使用）
- N-5　`ttl_hours` 変数で自動破棄を保証し、削除忘れを 0 件にする

────────────────────────────────────

## 3. セキュリティ要件

────────────────────────────────────

- S-1　演習用 IAMユーザー／ロールは最小権限（自アカウント外リソース不可）
- S-2　接続は AWS CloudShell か SSM Session Manager を使用し、SSH 鍵は公開しない
- S-3　CloudTrail はマネジメントプレーン（1 リージョン）のみ有効
- S-4　Budget アラートを「1 USD／日」「10 USD／月」で SNS 通知

────────────────────────────────────

## 4. 運用要件

────────────────────────────────────

- O-1　Makefile または bash スクリプト `run.sh` で start → `terraform init/plan/apply` ＆ destroy 予約
- O-2　EventBridge ルール（毎日 02:00）で強制 `terraform destroy` 実行
- O-3　GitHub など外部 CI は使わず、ローカル PC or CloudShell 上で直接実行
- O-4　追加シナリオは `/modules/<scenario>` フォルダを作り変数例を置くだけで拡張

────────────────────────────────────

## 5. 可観測性・ログ要件

────────────────────────────────────

- M-1　CloudWatch エージェントは演習開始時に ON、destroy 時に OFF
- M-2　ログは S3 Intelligent-Tiering に転送し 30 日でライフサイクル削除
- M-3　ログ保管サイズが 1 GB/月 を超えないこと
────────────────────────────────────

## 6. コスト要件

────────────────────────────────────

- C-1　「演習実行コスト」：全シナリオを同時起動しても 0.06 USD／2h 以内
- C-2　「月額固定コスト」：スナップショット＋ログ＋CloudTrail 合計 5 USD 未満
- C-3　Budgets 超過時は自動 destroy または SNS 通知後に手動対応

────────────────────────────────────

## 7. 技術スタック／構成詳細

────────────────────────────────────

- Metasploitable2　　→ Spot t4g.micro, パブリック IP, SG 制限のみ
- Juice Shop　　　　　→ Fargate Spot 0.5vCPU/1GB + API Gateway HTTP API
- TerraGoat　　　　　 → S3, Lambda, DynamoDB（全て無料枠）
- iam-vulnerable　　　 → IAM, Policy のみ（料金ゼロ）
- CloudGoat / AWSGoat→ 必要な EC2/RDS を最小構成で Spot & RDS 停止モード
- すべての VPC はパブリックサブネットのみ、IGW 経由で直接通信
- IaC lint 等の CI 工程はローカル実行（tflint / tfsec）

────────────────────────────────────

## 8. 実装タスク

────────────────────────────────────

1. Terraform リポジトリ初期化（backend local）
2. `/modules` にシナリオ別モジュールを作成（依存ゼロ設計）
3. 共通変数 `ttl_hours`, `my_ip_cidr` を定義
4. `run.sh`（または Makefile）で start/stop ラッパー実装
5. EventBridge + Lambda で "日次強制 destroy" をデプロイ
6. AWS Budgets & SNS 通知設定
7. 動作検証 → README に手順・料金目安を明記

これらの要件を満たせば、個人学習でも安全かつ月 5 USD
以内で複数の脆弱シナリオを自由に構築・破棄できる Terraform
ベースの環境が実現できます。
