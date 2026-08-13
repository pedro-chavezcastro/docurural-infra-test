################################################################################
# DocuRural — Entorno SHARED
# variables.tf — Definición de variables de entrada
#
# Los valores van en terraform.tfvars (ver terraform.tfvars.example).
# NUNCA subir terraform.tfvars a Git.
################################################################################

variable "aws_region" {
  description = "Región AWS"
  type        = string
  default     = "us-east-1"
}

variable "function_name" {
  description = "Nombre de la función Lambda del relay"
  type        = string
  default     = "docurural-github-webhook-relay"
}

variable "github_webhook_secret" {
  description = "Secret del webhook de organización de GitHub. Generar con: openssl rand -hex 32"
  type        = string
  sensitive   = true
}

variable "github_dispatch_token" {
  description = "PAT (classic, scope 'repo') usado para el repository_dispatch hacia target_repo"
  type        = string
  sensitive   = true
}

variable "target_repo" {
  description = "Repositorio destino del repository_dispatch, formato owner/repo"
  type        = string
  default     = "CCPL-Solutions/project-automation"
}
