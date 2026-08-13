################################################################################
# DocuRural — Módulo GitHub Webhook Relay — variables.tf
################################################################################

variable "function_name" {
  description = "Nombre de la función Lambda"
  type        = string
  default     = "docurural-github-webhook-relay"
}

variable "github_webhook_secret" {
  description = "Secret del webhook de organización de GitHub, usado para verificar X-Hub-Signature-256. Generar con: openssl rand -hex 32"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.github_webhook_secret) >= 32
    error_message = "El webhook secret debe tener al menos 32 caracteres (usar openssl rand -hex 32)."
  }
}

variable "github_dispatch_token" {
  description = "PAT (classic, scope 'repo') usado para disparar el repository_dispatch en target_repo"
  type        = string
  sensitive   = true
}

variable "target_repo" {
  description = "Repositorio destino del repository_dispatch, formato owner/repo"
  type        = string
  default     = "CCPL-Solutions/docurural-backend"

  validation {
    condition     = can(regex("^[^/\\s]+/[^/\\s]+$", var.target_repo))
    error_message = "target_repo debe tener el formato owner/repo."
  }
}
