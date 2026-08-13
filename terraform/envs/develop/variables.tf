################################################################################
# DocuRural — Entorno DEVELOP
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

variable "instance_type" {
  description = "Tipo de instancia EC2. DEVELOP usa t3.micro por defecto (entorno liviano; ver advertencia de swap en el módulo ec2)"
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key_path" {
  description = "Ruta al archivo .pub de la clave SSH de DEVELOP"
  type        = string
  default     = "~/.ssh/docurural-develop-key.pub"
}

variable "admin_ip" {
  description = "IP del administrador con acceso SSH (CIDR /32)"
  type        = string
}

variable "qa_ips" {
  description = "IPs con acceso a PostgreSQL puerto 5432 desde PgAdmin"
  type        = list(string)

  validation {
    condition     = length(var.qa_ips) > 0
    error_message = "Debe especificar al menos una IP para acceso a PostgreSQL."
  }
}

variable "route53_zone_id" {
  description = "ID de la Hosted Zone de Route 53"
  type        = string
}

variable "domain_name" {
  description = "FQDN del entorno DEVELOP (ej: dev.ccplsolutions.link)"
  type        = string
  default     = "dev.ccplsolutions.link"
}

variable "certbot_email" {
  description = "Email para notificaciones de expiración del certificado SSL"
  type        = string
}

variable "db_password" {
  description = "Contraseña de PostgreSQL (mínimo 12 caracteres)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 12
    error_message = "La contraseña debe tener al menos 12 caracteres."
  }
}

variable "admin_seed_email" {
  description = "Email del usuario administrador inicial"
  type        = string
  default     = "admin@dev.docurural.co"
}

variable "admin_seed_password" {
  description = "Contraseña del administrador inicial (mínimo 8 caracteres)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_seed_password) >= 8
    error_message = "La contraseña debe tener al menos 8 caracteres."
  }
}

variable "github_pat" {
  description = "Personal Access Token de GitHub (permisos: repo, packages:read)"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "Repositorio backend (formato owner/repo)"
  type        = string
}

variable "github_repo_frontend" {
  description = "Repositorio frontend (formato owner/repo)"
  type        = string
}

variable "bucket_docs_name" {
  description = "Nombre del bucket S3 de documentos para DEVELOP"
  type        = string
  default     = "docurural-develop-documentos"
}

variable "bucket_backups_name" {
  description = "Nombre del bucket S3 de backups para DEVELOP"
  type        = string
  default     = "docurural-develop-backups"
}

variable "cloudwatch_log_group" {
  description = "Nombre del log group de CloudWatch para DEVELOP"
  type        = string
  default     = "/docurural-develop/app"
}

variable "budget_limit" {
  description = "Límite del presupuesto mensual en USD (DEVELOP: 10)"
  type        = number
  default     = 10
}

variable "jwt_secret" {
  description = "Clave secreta para firma de tokens JWT (mínimo 32 caracteres). Generar con: openssl rand -base64 48"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.jwt_secret) >= 32
    error_message = "El JWT secret debe tener al menos 32 caracteres."
  }
}

variable "alert_email" {
  description = "Email para alertas de billing"
  type        = string
}
