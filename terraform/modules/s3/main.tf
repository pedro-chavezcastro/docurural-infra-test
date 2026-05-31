################################################################################
# DocuRural — Módulo S3
# Tres buckets:
#   1. documentos  — almacenamiento primario de archivos de la app (S3 privado)
#   2. backups     — destino de pg_dump diario; lifecycle 90 días
#   3. scripts     — bucket privado para el user_data del EC2
#
# spec §6.1-6.3 y §14.1
################################################################################

resource "random_id" "scripts_suffix" {
  byte_length = 4
}

# ── Bucket de documentos ──────────────────────────────────────────────────────

resource "aws_s3_bucket" "docs" {
  bucket = var.bucket_docs_name

  tags = {
    Name        = var.bucket_docs_name
    Environment = var.env
    Project     = "DocuRural"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "docs" {
  bucket = aws_s3_bucket.docs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning: Enabled en PROD para recuperar versiones borradas/sobreescritas (spec §14.1.1)
resource "aws_s3_bucket_versioning" "docs" {
  bucket = aws_s3_bucket.docs.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# ── Bucket de backups ─────────────────────────────────────────────────────────

resource "aws_s3_bucket" "backups" {
  bucket = var.bucket_backups_name

  tags = {
    Name        = var.bucket_backups_name
    Environment = var.env
    Project     = "DocuRural"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle: eliminar backups de más de 90 días (spec §6.3)
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "eliminar-backups-viejos"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

# ── Bucket de scripts (user_data) ─────────────────────────────────────────────
# Nombre con sufijo aleatorio para garantizar unicidad global en S3

resource "aws_s3_bucket" "scripts" {
  bucket = "docurural-${var.env}-scripts-${random_id.scripts_suffix.hex}"

  tags = {
    Name        = "docurural-${var.env}-scripts"
    Environment = var.env
    Project     = "DocuRural"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "scripts" {
  bucket = aws_s3_bucket.scripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
