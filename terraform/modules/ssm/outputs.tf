################################################################################
# DocuRural — Módulo SSM — outputs.tf
################################################################################

output "db_password_arn" {
  description = "ARN del parámetro SSM db-password"
  value       = aws_ssm_parameter.db_password.arn
}

output "jwt_secret_arn" {
  description = "ARN del parámetro SSM jwt-secret"
  value       = aws_ssm_parameter.jwt_secret.arn
}

output "parameter_path" {
  description = "Path base de los parámetros SSM de este entorno"
  value       = "/docurural/${var.env}"
}
