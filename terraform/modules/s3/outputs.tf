################################################################################
# DocuRural — Módulo S3 — outputs.tf
################################################################################

output "docs_bucket_name" {
  description = "Nombre del bucket S3 de documentos"
  value       = aws_s3_bucket.docs.bucket
}

output "docs_bucket_arn" {
  description = "ARN del bucket S3 de documentos"
  value       = aws_s3_bucket.docs.arn
}

output "backups_bucket_name" {
  description = "Nombre del bucket S3 de backups"
  value       = aws_s3_bucket.backups.bucket
}

output "backups_bucket_arn" {
  description = "ARN del bucket S3 de backups"
  value       = aws_s3_bucket.backups.arn
}

output "scripts_bucket_name" {
  description = "Nombre del bucket S3 de scripts (user_data)"
  value       = aws_s3_bucket.scripts.bucket
}

output "scripts_bucket_id" {
  description = "ID del bucket S3 de scripts (para aws_s3_object)"
  value       = aws_s3_bucket.scripts.id
}

output "scripts_bucket_arn" {
  description = "ARN del bucket S3 de scripts"
  value       = aws_s3_bucket.scripts.arn
}
