################################################################################
# DocuRural -Módulo SSM Parameter Store
# 5 parámetros bajo /docurural/<env>/* (spec §7.1)
# SecureString para secretos; String para valores no sensibles.
#
# ⚠  IMPORTANTE SOBRE EL STATE: los valores SecureString (db-password, jwt-secret)
# quedan cifrados en AWS pero en TEXTO PLANO en el tfstate local. El tfstate ya está
# en .gitignore. Para mayor seguridad, usar un backend S3 con encrypt=true y lock
# DynamoDB. Ver README.md para instrucciones de bootstrap del backend remoto.
################################################################################

resource "aws_ssm_parameter" "db_password" {
  name        = "/docurural/${var.env}/db-password"
  description = "Contraseña del usuario docurural_user en PostgreSQL -entorno ${var.env}"
  type        = "SecureString"
  value       = var.db_password

  tags = {
    Environment = var.env
    Project     = "DocuRural"
    ManagedBy   = "Terraform"
  }
}

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "/docurural/${var.env}/jwt-secret"
  description = "Clave secreta JWT -entorno ${var.env}"
  type        = "SecureString"
  value       = var.jwt_secret

  tags = {
    Environment = var.env
    Project     = "DocuRural"
    ManagedBy   = "Terraform"
  }
}

resource "aws_ssm_parameter" "s3_bucket_docs" {
  name        = "/docurural/${var.env}/s3-bucket-docs"
  description = "Nombre del bucket S3 de documentos -entorno ${var.env}"
  type        = "String"
  value       = var.bucket_docs_name

  tags = {
    Environment = var.env
    Project     = "DocuRural"
    ManagedBy   = "Terraform"
  }
}

resource "aws_ssm_parameter" "s3_bucket_backups" {
  name        = "/docurural/${var.env}/s3-bucket-backups"
  description = "Nombre del bucket S3 de backups -entorno ${var.env}"
  type        = "String"
  value       = var.bucket_backups_name

  tags = {
    Environment = var.env
    Project     = "DocuRural"
    ManagedBy   = "Terraform"
  }
}

resource "aws_ssm_parameter" "aws_region" {
  name        = "/docurural/${var.env}/aws-region"
  description = "Región AWS -entorno ${var.env}"
  type        = "String"
  value       = var.aws_region

  tags = {
    Environment = var.env
    Project     = "DocuRural"
    ManagedBy   = "Terraform"
  }
}
