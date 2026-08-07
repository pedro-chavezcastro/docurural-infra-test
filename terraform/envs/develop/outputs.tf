################################################################################
# DocuRural — Entorno DEVELOP — outputs.tf
################################################################################

output "elastic_ip" {
  description = "IP pública fija de la instancia DEVELOP (usar para PgAdmin — NO el dominio)"
  value       = module.ec2.elastic_ip
}

output "url_aplicacion" {
  description = "URL de acceso al sistema DocuRural DEVELOP (disponible ~10-15 min después del apply)"
  value       = "https://${var.domain_name}"
}

output "api_base_url" {
  description = "Base URL de la API para Postman (responde 502 hasta que el runner de CI/CD despliegue el JAR)"
  value       = "https://${var.domain_name}/api"
}

output "ssh_command" {
  description = "Comando SSH para conectarse a la instancia DEVELOP"
  value       = "ssh -i ~/.ssh/docurural-develop-key.pem ubuntu@${module.ec2.elastic_ip}"
}

output "pgadmin_host" {
  description = "Host para PgAdmin en DEVELOP (IP directa, no el dominio)"
  value       = module.ec2.elastic_ip
}

output "instance_id" {
  description = "ID de la instancia EC2 DEVELOP"
  value       = module.ec2.instance_id
}

output "s3_docs_bucket" {
  description = "Bucket S3 de documentos DEVELOP"
  value       = module.s3.docs_bucket_name
}

output "s3_backups_bucket" {
  description = "Bucket S3 de backups DEVELOP"
  value       = module.s3.backups_bucket_name
}

output "cloudwatch_log_group" {
  description = "Log group de CloudWatch para DEVELOP"
  value       = module.cloudwatch.log_group_name
}

output "nota_costos" {
  description = "Recordatorio de control de costos DEVELOP"
  value       = "DEVELOP: apagar la instancia manualmente desde la consola EC2 al terminar pruebas. El EBS se cobra aunque la instancia esté detenida. Usar 'terraform destroy' para eliminar todo."
}
