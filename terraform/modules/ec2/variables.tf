################################################################################
# DocuRural — Módulo EC2
# variables.tf
################################################################################

variable "env" {
  description = "Entorno: 'develop', 'qa' o 'prod'"
  type        = string
}

variable "aws_region" {
  description = "Región AWS"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2. Mínimo recomendado: t3.small (Spring Boot + PostgreSQL + Nginx)"
  type        = string
  default     = "t3.small"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Usar t3.small (recomendado) o t3.medium. t3.micro es válido solo para entornos livianos (ej. develop): con Spring Boot + PostgreSQL + runners de CI/CD compilando, hay riesgo de OOM incluso con swap configurado."
  }
}

variable "ebs_size" {
  description = "Tamaño del disco EBS raíz en GB. QA: 20, PROD: 30."
  type        = number
  default     = 20
}

variable "key_name" {
  description = "Nombre del key pair EC2 que se creará"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Ruta al archivo de clave pública SSH (.pub)"
  type        = string
}

variable "admin_ip" {
  description = "IP del administrador con acceso SSH (formato CIDR, ej: 190.x.x.x/32)"
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_ip, 0))
    error_message = "Debe ser una dirección IP válida en formato CIDR (ej: 190.x.x.x/32)."
  }
}

variable "qa_ips" {
  description = "Lista de IPs con acceso a PostgreSQL puerto 5432 (solo QA). Lista vacía en PROD cierra el puerto."
  type        = list(string)
  default     = []
}

variable "iam_instance_profile" {
  description = "Nombre del IAM Instance Profile a asignar al EC2"
  type        = string
}

variable "scripts_bucket_id" {
  description = "ID del bucket S3 donde se sube el user_data.sh renderizado"
  type        = string
}

variable "scripts_bucket_name" {
  description = "Nombre del bucket S3 de scripts (para el bootstrap del EC2)"
  type        = string
}

variable "domain_name" {
  description = "FQDN del entorno (ej: pruebas.ccplsolutions.link)"
  type        = string
}

variable "certbot_email" {
  description = "Email para Let's Encrypt (notificaciones de expiración de certificado)"
  type        = string
}

# ── Secretos ──────────────────────────────────────────────────────────────────

variable "db_password" {
  description = "Contraseña del usuario docurural_user en PostgreSQL (se usa solo para crear el usuario; no se escribe en .env)"
  type        = string
  sensitive   = true
}

variable "admin_seed_email" {
  description = "Email del usuario administrador inicial (seed de Flyway)"
  type        = string
}

variable "admin_seed_password" {
  description = "Contraseña del usuario administrador inicial"
  type        = string
  sensitive   = true
}

variable "github_pat" {
  description = "Personal Access Token de GitHub para registrar los runners self-hosted"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "Repositorio backend en formato owner/repo (ej: pedro-chavezcastro/docurural-backend)"
  type        = string
}

variable "github_repo_frontend" {
  description = "Repositorio frontend en formato owner/repo"
  type        = string
}

# ── Configuración por entorno ─────────────────────────────────────────────────

variable "cloudwatch_log_group" {
  description = "Nombre del log group de CloudWatch (ej: /docurural-qa/app)"
  type        = string
}

variable "spring_profile" {
  description = "Perfil de Spring Boot activo: 'develop', 'qa' o 'prod'. Debe coincidir con var.env (backup.sh lee /docurural/<spring_profile>/db-password)."
  type        = string
}

variable "jwt_expiration_ms" {
  description = "Expiración del token JWT en milisegundos. QA: 1800000 (30 min), PROD: 28800000 (8 h)"
  type        = number
}

variable "bucket_docs_name" {
  description = "Nombre del bucket S3 de documentos (se escribe en .env)"
  type        = string
}

variable "bucket_backups_name" {
  description = "Nombre del bucket S3 de backups (se escribe en .env y usa backup.sh)"
  type        = string
}

variable "pg_remote_access" {
  description = "Exponer PostgreSQL en 0.0.0.0 para acceso remoto desde PgAdmin. true solo en QA."
  type        = bool
  default     = false
}

variable "runner_name_backend" {
  description = "Nombre del runner self-hosted de GitHub Actions para el backend"
  type        = string
}

variable "runner_name_frontend" {
  description = "Nombre del runner self-hosted de GitHub Actions para el frontend"
  type        = string
}

variable "runner_labels_backend" {
  description = "Labels del runner backend separados por coma (ej: qa,docurural-backend)"
  type        = string
}

variable "runner_labels_frontend" {
  description = "Labels del runner frontend separados por coma (ej: qa,docurural-frontend)"
  type        = string
}

variable "ami_id" {
  description = "ID de la AMI de Ubuntu 24.04 LTS. Se pasa desde el root module (data source)."
  type        = string
}
