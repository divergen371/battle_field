# プロジェクト進捗状況

## リポジトリ初期化 & 基本構成

- [x] 1-1. ★3 Gitリポジトリ初期化・ディレクトリ作成（/modules /scripts /examples /doc）
- [x] 1-2. ★3 backend "local"を記述した共通main.tf雛形作成
- [x] 1-3. ★3 入力変数ファイルvariables.tfに変数定義（ttl_hours, my_ip_cidr, scenario_name）
- [x] 1-4. ★2 Makefile or scripts/run.shの作成（start/stopサブルール）

## 共通ライブラリ/ユーティリティ

- [x] 2-1a. ★3 TTL自動破棄ロジック（null_resource + local-exec）
- [x] 2-1b. ★2 TTL自動破棄ロジック（EventBridge → Lambda 00:00実行）【実行順序: 8】
- [x] 2-2. ★2 SGテンプレート（許可CIDRだけ変数）
- [ ] 2-3. ★1 CloudTrail（マネジメントプレーンのみ）モジュール【実行順序: 12】
- [ ] 2-4. ★1 CloudWatch Agent ON/OFF toggle Script（EC2用）【実行順序: 13】

## シナリオ別モジュール作成

- [x] 3-1. ★3 metasploitable2モジュール
- [x] 3-2. ★3 juice_shopモジュール
- [x] 3-3. ★3 terra_goatモジュール【実行順序: 2】
- [x] 3-4. ★3 iam_vulnerableモジュール【実行順序: 3】
- [x] 3-5. ★2 cloudgoat_minモジュール【実行順序: 9】
- [ ] 3-6. ★1 awsgoat_minモジュール【実行順序: 14】

## スクリプト & UX

- [x] 4-1. ★3 scripts/run.sh実装（start/stop機能）
- [x] 4-2. ★2 scripts/check_cost.sh（AWS CLIで当日使用額を取得）
- [ ] 4-3. ★1 scripts/lint.sh（terraform fmt -check / tflint / tfsec）【実行順序: 15】

## コスト・セキュリティガード

- [x] 5-1. ★3 AWS Budgets 10 USD/月, 1 USD/日作成スクリプト【実行順序: 1】
- [x] 5-2. ★2 SNS Topic + Email/Slack Webhook通知【実行順序: 7】
- [ ] 5-3. ★1 IAMロール：演習用最小ポリシー【実行順序: 11】

## ドキュメント & サンプル

- [x] 6-1. ★2 README.md：前提・使い方・注意点・料金例
- [x] 6-2. ★2 examplesにサンプル設定ファイル配置
- [ ] 6-3. ★1 ラボの手順書とコスト試算表追記【実行順序: 16】

## 動作検証 & リリース

- [ ] 7-1. ★3 全シナリオでmake start → 2h → auto-destroyテスト【実行順序: 10】
- [ ] 7-2. ★2 破棄後に課金対象リソースが残らないことを確認【実行順序: 17】
- [ ] 7-3. ★1 リポジトリ初版タグ付け・公開【実行順序: 18】

## 保守性・信頼性向上タスク

- [x] 8-1a. ★3 scripts/check_cost.sh → check_cost.py（boto3利用）への移行【実行順序: 4】
- [x] 8-1b. ★2 scripts/run.sh → run.py（サブコマンド対応）への移行【実行順序: 5】
- [x] 8-2a. ★2 エラーハンドリング改善【実行順序: 6】
- [x] 8-2b. ★2 ロギング機能追加【実行順序: 6】
- [x] 8-2c. ★1 設定ファイル対応（YAML/JSON）【実行順序: 6】
- [x] 8-3a. ★1 Pytest導入【実行順序: 6】
- [x] 8-3b. ★1 Type hints追加（mypy対応）【実行順序: 6】

## 実行計画（フェーズ別）

### フェーズ1: コスト管理とコア機能拡張

1. [x] ★3 AWS Budgets 10 USD/月, 1 USD/日作成スクリプト - コスト超過防止の最重要タスク
2. [x] ★3 terra_goatモジュール実装 - 主要な脆弱性シナリオの追加
3. [x] ★3 iam_vulnerableモジュール実装 - IAMに特化した脆弱性シナリオ

### フェーズ2: スクリプト改善とコード品質向上

4. [x] ★3 scripts/check_cost.sh → check_cost.py（boto3利用）への移行 - コスト管理ツールの改善
5. [x] ★2 scripts/run.sh → run.py（サブコマンド対応）への移行 - 主要スクリプトの改善
6. [x] ★2 Python移行後の機能強化（エラーハンドリング、ロギング、設定ファイル、テスト） - コード品質向上

### フェーズ3: 追加機能と通知

7. [x] ★2 SNS Topic + Email/Slack Webhook通知 - アラート通知の実装
8. [x] ★2 EventBridge自動破棄（Lambda 00:00実行） - バックアップ破棄メカニズム
9. [x] ★2 cloudgoat_minモジュール実装 - 追加シナリオ

### フェーズ4: 検証と仕上げ

10. [ ] ★3 全シナリオでテスト - 統合テスト
11. [ ] ★1 IAMロール：演習用最小ポリシー - セキュリティ強化
12. [ ] ★1 CloudTrailモジュール - 監査機能
13. [ ] ★1 CloudWatch Agent Script - モニタリング機能
14. [ ] ★1 awsgoat_minモジュール - 最終シナリオ追加
15. [ ] ★1 scripts/lint.sh - コード品質チェック
16. [ ] ★1 ラボの手順書とコスト試算表 - ドキュメント仕上げ
17. [ ] ★2 リソース削除確認 - 最終確認
18. [ ] ★1 リポジトリ初版タグ付け・公開 - 完成

## 現在の進捗状況

- 完了タスク: 22/29 (約76%)
- 未完了タスク: 7/29 (約24%)

## 次に優先すべきタスク（再評価後）

1. [ ] ★3 全シナリオでテスト（機能検証）
2. [ ] ★1 IAMロール：演習用最小ポリシー（セキュリティ強化）
3. [ ] ★1 CloudTrailモジュール（監査機能）
4. [ ] ★1 CloudWatch Agent Script（モニタリング機能）
5. [ ] ★1 scripts/lint.sh（コード品質チェック）
