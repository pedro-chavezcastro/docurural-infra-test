################################################################################
# DocuRural — Módulo S3
# variables.tf
################################################################################

variable "env" {
  description = "Entorno: 'test' (QA) o 'prod'"
  type        = string
}

variable "bucket_docs_name" {
  description = "Nombre del bucket S3 para documentos de la aplicación"
  type        = string
}

variable "bucket_backups_name" {
  description = "Nombre del bucket S3 para backups de PostgreSQL"
  type        = string
}

variable "enable_versioning" {
  description = "Habilitar S3 Versioning en el bucket de documentos (recomendado en PROD para recuperar versiones anteriores)"
  type        = bool
  default     = false
}
