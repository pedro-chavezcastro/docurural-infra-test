################################################################################
# DocuRural — Entorno QA — outputs.tf
################################################################################

output "elastic_ip" {
  description = "IP pública fija de la instancia QA (usar para PgAdmin — NO el dominio)"
  value       = module.ec2.elastic_ip
}

output "url_aplicacion" {
  description = "URL de acceso al sistema DocuRural QA (disponible ~10-15 min después del apply)"
  value       = "https://${var.domain_name}"
}

output "api_base_url" {
  description = "Base URL de la API para Postman (responde 502 hasta que el runner de CI/CD despliegue el JAR)"
  value       = "https://${var.domain_name}/api"
}

output "ssh_command" {
  description = "Comando SSH para conectarse a la instancia QA"
  value       = "ssh -i ~/.ssh/docurural-qa-key.pem ubuntu@${module.ec2.elastic_ip}"
}

output "pgadmin_host" {
  description = "Host para PgAdmin en QA (IP directa, no el dominio)"
  value       = module.ec2.elastic_ip
}

output "instance_id" {
  description = "ID de la instancia EC2 QA"
  value       = module.ec2.instance_id
}

output "s3_docs_bucket" {
  description = "Bucket S3 de documentos QA"
  value       = module.s3.docs_bucket_name
}

output "s3_backups_bucket" {
  description = "Bucket S3 de backups QA"
  value       = module.s3.backups_bucket_name
}

output "cloudwatch_log_group" {
  description = "Log group de CloudWatch para QA"
  value       = module.cloudwatch.log_group_name
}

output "nota_costos" {
  description = "Recordatorio de control de costos QA"
  value       = "QA: apagar la instancia manualmente desde la consola EC2 al terminar pruebas. El EBS (~$1.60/mes) se cobra aunque la instancia esté detenida. Usar 'terraform destroy' para eliminar todo."
}
