variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックス）"
  type        = string
  default     = "pentest-lab"
}

variable "my_ip_cidr" {
  description = "アクセスを許可するIPアドレス（CIDR形式）"
  type        = string
}

variable "ttl_hours" {
  description = "リソースの生存期間（時間）"
  type        = number
  default     = 2
}

# リソース名
locals {
  name_prefix = "${var.project_name}-iam-vulnerable"
}

# 1. 脆弱なIAMユーザー（パスワードポリシーなし、長期アクセスキー）
resource "aws_iam_user" "vulnerable_user" {
  name = "${local.name_prefix}-user"
  path = "/vulnerable/"

  tags = {
    Name     = "${local.name_prefix}-user"
    TTL      = "${var.ttl_hours}h"
    Scenario = "iam_vulnerable"
  }
}

# 2. 脆弱：コンソールアクセス用のパスワード（ハードコード）
resource "aws_iam_user_login_profile" "vulnerable_profile" {
  user                    = aws_iam_user.vulnerable_user.name
  password_reset_required = false
  pgp_key                 = null  # 脆弱: 暗号化なしのパスワード
  password_length         = 8     # 脆弱: 短いパスワード
}

# 3. 脆弱：ローテーションなしのアクセスキー
resource "aws_iam_access_key" "vulnerable_key" {
  user = aws_iam_user.vulnerable_user.name
}

# 4. 脆弱：過剰な権限を持つグループ
resource "aws_iam_group" "vulnerable_group" {
  name = "${local.name_prefix}-group"
  path = "/vulnerable/"
}

# 5. 脆弱：ユーザーを脆弱なグループに追加
resource "aws_iam_user_group_membership" "vulnerable_membership" {
  user   = aws_iam_user.vulnerable_user.name
  groups = [aws_iam_group.vulnerable_group.name]
}

# 6. 脆弱：グループに過剰な権限（管理者アクセス）を付与
resource "aws_iam_group_policy" "vulnerable_policy" {
  name  = "${local.name_prefix}-admin-policy"
  group = aws_iam_group.vulnerable_group.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# 7. 脆弱：制限のないバケットアクセスポリシー
resource "aws_iam_user_policy" "vulnerable_s3_policy" {
  name = "${local.name_prefix}-s3-policy"
  user = aws_iam_user.vulnerable_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# 8. 脆弱：誰でも引き受け可能なロール
resource "aws_iam_role" "vulnerable_role" {
  name = "${local.name_prefix}-role"
  path = "/vulnerable/"

  # 脆弱：任意のAWSアカウントが引き受け可能
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { "AWS": "*" }  # 脆弱: すべてのAWSプリンシパルが引き受け可能
      }
    ]
  })

  tags = {
    Name     = "${local.name_prefix}-role"
    TTL      = "${var.ttl_hours}h"
    Scenario = "iam_vulnerable"
  }
}

# 9. 脆弱：制限のないEC2アクセスポリシー
resource "aws_iam_role_policy" "vulnerable_ec2_policy" {
  name = "${local.name_prefix}-ec2-policy"
  role = aws_iam_role.vulnerable_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "ec2:*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# 10. 脆弱：不適切な条件のIAMポリシー
resource "aws_iam_policy" "vulnerable_custom_policy" {
  name        = "${local.name_prefix}-custom-policy"
  path        = "/vulnerable/"
  description = "脆弱なカスタムポリシー"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "secretsmanager:Get*"
        Effect   = "Allow"
        Resource = "*"
        # 脆弱: IPアドレス制限がないためどこからでもアクセス可能
      },
      {
        Action   = "kms:Decrypt"
        Effect   = "Allow"
        Resource = "*"
        # 脆弱: 暗号化キーへの無制限アクセス
      }
    ]
  })
}

# 11. 脆弱：カスタムポリシーをユーザーにアタッチ
resource "aws_iam_user_policy_attachment" "vulnerable_policy_attachment" {
  user       = aws_iam_user.vulnerable_user.name
  policy_arn = aws_iam_policy.vulnerable_custom_policy.arn
}

# 12. 脆弱：過度に寛容なバケットポリシー
resource "aws_iam_policy" "vulnerable_bucket_policy" {
  name        = "${local.name_prefix}-bucket-policy"
  path        = "/vulnerable/"
  description = "脆弱なS3バケットポリシー"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:PutObject"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::*/*"
        # 脆弱: すべてのバケットにオブジェクトを配置可能
      }
    ]
  })
}

# 13. 脆弱：MFAなしのアクセスを許可するポリシー
resource "aws_iam_policy" "no_mfa_policy" {
  name        = "${local.name_prefix}-no-mfa-policy"
  path        = "/vulnerable/"
  description = "MFAなしでのアクセスを許可する脆弱なポリシー"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:ListUsers",
          "iam:GetAccountSummary"
        ]
        Resource = "*"
        # 脆弱: MFA条件がないため、MFAなしでアクセス可能
      }
    ]
  })
}

# 自動破棄ロジック
resource "null_resource" "ttl_destroyer" {
  provisioner "local-exec" {
    # TTL時間経過後にterraform destroyを実行
    command = <<EOT
      sleep ${var.ttl_hours * 60 * 60} && \
      cd ${path.module}/../../ && \
      terraform destroy -auto-approve -var="scenario_name=iam_vulnerable" || echo "自動破棄に失敗しました"
    EOT
    
    # バックグラウンドで実行
    on_failure = continue
    interpreter = ["/bin/bash", "-c"]
  }

  # リソース更新時は既存のものを破棄して新しく作り直し
  triggers = {
    always_run = "${timestamp()}"
  }
}

# 安全上の問題から、アクセスキーは出力しません
output "iam_vulnerable_password" {
  description = "脆弱なIAMユーザーのパスワード（本番環境では絶対に使用しないでください）"
  value       = aws_iam_user_login_profile.vulnerable_profile.password
  sensitive   = true
}

output "iam_vulnerable_instructions" {
  description = "IAM脆弱性環境の使用手順"
  value       = <<EOT
IAM脆弱性検証環境のご利用方法:

この環境では、以下のようなIAM関連の脆弱性が含まれています:
1. 安全でないパスワードポリシー（短いパスワード、ローテーションなし）
2. 長期的なアクセスキー（ローテーションなし）
3. 過剰な権限のIAMグループとロール
4. 制限のないリソースアクセス（"*"の使用）
5. 不適切なクロスアカウントアクセス設定
6. MFA認証の欠如

検証用IAMユーザー:
- ユーザー名: ${aws_iam_user.vulnerable_user.name}
- パスワード: （セキュリティ上の理由で非表示 - terraform output -raw iam_vulnerable_passwordで表示）

注意：
- これらのリソースは学習・検証目的のみに使用してください
- ${var.ttl_hours}時間後に自動的に削除されます
- 実際の環境では、これらの脆弱性を修正することが必要です

推奨される検証手順:
1. AWS IAM AccessAnalyzerを使用して問題を特定する
2. AWS CLIで「aws iam get-account-authorization-details」を実行
3. スクリプトやツールを使用してポリシーの脆弱性を分析

この環境は自動的に${var.ttl_hours}時間後に削除されますが、
作業後は「terraform destroy -var="scenario_name=iam_vulnerable"」で手動削除することも可能です。
EOT
} 