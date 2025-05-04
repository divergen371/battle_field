# シナリオ選択に基づいて条件付きでモジュールを実行

# Metasploitable2シナリオ
module "metasploitable2" {
  source = "./modules/metasploitable2"
  
  # scenario_nameがmetasploitable2またはallの場合にのみ実行
  count = var.scenario_name == "metasploitable2" || var.scenario_name == "all" ? 1 : 0
  
  project_name = var.project_name
  my_ip_cidr   = var.my_ip_cidr
  ttl_hours    = var.ttl_hours
}

/* この後、以下のモジュールを順次実装
module "juice_shop" {
  source = "./modules/juice_shop"
  count  = var.scenario_name == "juice_shop" || var.scenario_name == "all" ? 1 : 0
  ...
}

module "terra_goat" {
  source = "./modules/terra_goat"
  count  = var.scenario_name == "terra_goat" || var.scenario_name == "all" ? 1 : 0
  ...
}

module "iam_vulnerable" {
  source = "./modules/iam_vulnerable"
  count  = var.scenario_name == "iam_vulnerable" || var.scenario_name == "all" ? 1 : 0
  ...
}

module "cloudgoat_min" {
  source = "./modules/cloudgoat_min"
  count  = var.scenario_name == "cloudgoat_min" || var.scenario_name == "all" ? 1 : 0
  ...
}

module "awsgoat_min" {
  source = "./modules/awsgoat_min"
  count  = var.scenario_name == "awsgoat_min" || var.scenario_name == "all" ? 1 : 0
  ...
}
*/ 