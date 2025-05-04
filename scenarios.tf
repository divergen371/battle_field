# シナリオ選択に基づいて条件付きでモジュールを実行

# 共通通知モジュール（常に実行）
module "notification" {
  source = "./modules/common/notification"
  
  project_name    = var.project_name
  email_addresses = var.notification_emails
  slack_webhook_url = var.slack_webhook_url
  ttl_hours       = var.ttl_hours
}

# 共通TTL破棄モジュール（各シナリオで使用、EventBridge自動破棄）
module "ttl_destroyer" {
  source = "./modules/common/ttl_destroyer"
  
  # メタスプロイタブル2またはジュースショップが実行されている場合のみ有効化
  count = var.scenario_name != "all" ? 1 : 0
  
  project_name  = var.project_name
  scenario_name = var.scenario_name
  sns_topic_arn = module.notification.sns_topic_arn
  ttl_hours     = var.ttl_hours
}

# Metasploitable2シナリオ
module "metasploitable2" {
  source = "./modules/metasploitable2"
  
  # scenario_nameがmetasploitable2またはallの場合にのみ実行
  count = var.scenario_name == "metasploitable2" || var.scenario_name == "all" ? 1 : 0
  
  project_name = var.project_name
  my_ip_cidr   = var.my_ip_cidr
  ttl_hours    = var.ttl_hours
}

# Juice Shopシナリオ
module "juice_shop" {
  source = "./modules/juice_shop"
  
  # scenario_nameがjuice_shopまたはallの場合にのみ実行
  count = var.scenario_name == "juice_shop" || var.scenario_name == "all" ? 1 : 0
  
  project_name = var.project_name
  my_ip_cidr   = var.my_ip_cidr
  ttl_hours    = var.ttl_hours
}

# TerraGoatシナリオ
module "terra_goat" {
  source = "./modules/terra_goat"
  
  # scenario_nameがterra_goatまたはallの場合にのみ実行
  count = var.scenario_name == "terra_goat" || var.scenario_name == "all" ? 1 : 0
  
  project_name = var.project_name
  my_ip_cidr   = var.my_ip_cidr
  ttl_hours    = var.ttl_hours
}

# IAM脆弱性シナリオ
module "iam_vulnerable" {
  source = "./modules/iam_vulnerable"
  
  # scenario_nameがiam_vulnerableまたはallの場合にのみ実行
  count = var.scenario_name == "iam_vulnerable" || var.scenario_name == "all" ? 1 : 0
  
  project_name = var.project_name
  my_ip_cidr   = var.my_ip_cidr
  ttl_hours    = var.ttl_hours
}

# CloudGoat Miniシナリオ
module "cloudgoat_min" {
  source = "./modules/cloudgoat_min"
  
  # scenario_nameがcloudgoat_minまたはallの場合にのみ実行
  count = var.scenario_name == "cloudgoat_min" || var.scenario_name == "all" ? 1 : 0
  
  project_name = var.project_name
  my_ip_cidr   = var.my_ip_cidr
  ttl_hours    = var.ttl_hours
}

/* この後、以下のモジュールを順次実装
module "awsgoat_min" {
  source = "./modules/awsgoat_min"
  count  = var.scenario_name == "awsgoat_min" || var.scenario_name == "all" ? 1 : 0
  ...
}
*/ 