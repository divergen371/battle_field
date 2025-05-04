# シナリオの出力（条件付き）

# Metasploitable2の出力
output "metasploitable2_public_ip" {
  description = "Metasploitable2のパブリックIP"
  value       = var.scenario_name == "metasploitable2" || var.scenario_name == "all" ? try(module.metasploitable2[0].metasploitable2_public_ip, "未デプロイ") : "未選択"
}

output "metasploitable2_instructions" {
  description = "Metasploitable2の接続手順"
  value       = var.scenario_name == "metasploitable2" || var.scenario_name == "all" ? try(module.metasploitable2[0].connection_instructions, "未デプロイ") : "未選択"
}

# 他のシナリオ出力は今後追加

# TTL自動破棄の時刻
output "auto_destroy_time" {
  description = "リソースの自動破棄予定時刻"
  value       = formatdate("YYYY-MM-DD HH:mm:ss", timeadd(timestamp(), "${var.ttl_hours}h"))
} 