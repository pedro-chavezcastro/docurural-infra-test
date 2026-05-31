################################################################################
# DocuRural — Módulo SSM Parameter Store
# variables.tf
################################################################################

variable "env" {
  description = "Entorno: 'test' (QA) o 'prod'"
  type        = string
}

variable "aws_region" {
  description = "Región AWS"
  type        = string
}

variable "db_password" {
  description = "Contraseña del usuario docurural_user en PostgreSQL"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Clave secreta para firma de tokens JWT (mínimo 32 caracteres)"
  type        = string
  sensitive   = true
}

variable "bucket_docs_name" {
  description = "Nombre del bucket S3 de documentos"
  type        = string
}

variable "bucket_backups_name" {
  description = "Nombre del bucket S3 de backups"
  type        = string
}
