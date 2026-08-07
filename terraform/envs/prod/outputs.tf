################################################################################
# DocuRural — Entorno PROD — outputs.tf
################################################################################

output "elastic_ip" {
  description = "IP pública fija de la instancia PROD"
  value       = module.ec2.elastic_ip
}

output "url_aplicacion" {
  description = "URL de acceso al sistema DocuRural PROD"
  value       = "https://${var.domain_name}"
}

output "api_base_url" {
  description = "Base URL de la API para Postman (responde 502 hasta que el runner de CI/CD despliegue el JAR)"
  value       = "https://${var.domain_name}/api"
}

output "ssh_command" {
  description = "Comando SSH para conectarse a la instancia PROD"
  value       = "ssh -i ~/.ssh/docurural-prod-key.pem ubuntu@${module.ec2.elastic_ip}"
}

output "ssh_tunnel_postgres" {
  description = "SSH tunnel para acceder a PostgreSQL PROD desde PgAdmin (el puerto 5432 está cerrado en el SG)"
  value       = "ssh -i ~/.ssh/docurural-prod-key.pem -L 5432:localhost:5432 ubuntu@${module.ec2.elastic_ip}"
}

output "instance_id" {
  description = "ID de la instancia EC2 PROD (útil para encender/apagar desde la CLI)"
  value       = module.ec2.instance_id
}

output "s3_docs_bucket" {
  description = "Bucket S3 de documentos PROD"
  value       = module.s3.docs_bucket_name
}

output "s3_backups_bucket" {
  description = "Bucket S3 de backups PROD"
  value       = module.s3.backups_bucket_name
}

output "cloudwatch_log_group" {
  description = "Log group de CloudWatch para PROD"
  value       = module.cloudwatch.log_group_name
}

output "scheduler_apagado_arn" {
  description = "ARN del schedule de apagado nocturno (10 PM Colombia, L–V)"
  value       = module.eventbridge.apagado_schedule_arn
}

output "scheduler_encendido_arn" {
  description = "ARN del schedule de encendido matutino (6 AM Colombia, L–V)"
  value       = module.eventbridge.encendido_schedule_arn
}
