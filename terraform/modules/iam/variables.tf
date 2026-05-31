################################################################################
# DocuRural — Módulo IAM
# variables.tf
################################################################################

variable "env" {
  description = "Entorno: 'qa' o 'prod'"
  type        = string
}

variable "aws_region" {
  description = "Región AWS donde viven los recursos (para construir ARNs de logs y SSM)"
  type        = string
}

variable "bucket_docs_arn" {
  description = "ARN del bucket S3 de documentos"
  type        = string
}

variable "bucket_backups_arn" {
  description = "ARN del bucket S3 de backups"
  type        = string
}

variable "bucket_scripts_arn" {
  description = "ARN del bucket S3 de scripts (user_data)"
  type        = string
}

variable "log_group_name" {
  description = "Nombre del log group de CloudWatch (ej: /docurural-qa/app). Se usa para construir el ARN de permiso."
  type        = string
}
