################################################################################
# DocuRural — Módulo EC2
# Security Group + Key Pair + user_data en S3 + Instancia + Elastic IP
#
# El user_data.sh supera el límite de 16 KB de AWS. Se renderiza con templatefile,
# se sube a S3 y el bootstrap mínimo del user_data lo descarga y ejecuta.
################################################################################

locals {
  common_tags = {
    Project     = "DocuRural"
    Environment = var.env
    ManagedBy   = "Terraform"
  }

  # Ruta al template desde este módulo: modules/ec2/ → ../../scripts/
  user_data_template_path = "${path.module}/../../scripts/user_data.sh.tftpl"
}

# ── Render y subida del user_data a S3 ───────────────────────────────────────

resource "aws_s3_object" "user_data_script" {
  bucket = var.scripts_bucket_id
  key    = "user_data.sh"

  content = templatefile(local.user_data_template_path, {
    db_password            = var.db_password
    admin_seed_email       = var.admin_seed_email
    admin_seed_password    = var.admin_seed_password
    domain_name            = var.domain_name
    certbot_email          = var.certbot_email
    github_pat             = var.github_pat
    github_repo            = var.github_repo
    github_repo_frontend   = var.github_repo_frontend
    cloudwatch_log_group   = var.cloudwatch_log_group
    spring_profile         = var.spring_profile
    jwt_expiration_ms      = var.jwt_expiration_ms
    bucket_docs_name       = var.bucket_docs_name
    bucket_backups_name    = var.bucket_backups_name
    aws_region             = var.aws_region
    pg_remote_access       = var.pg_remote_access
    runner_name_backend    = var.runner_name_backend
    runner_name_frontend   = var.runner_name_frontend
    runner_labels_backend  = var.runner_labels_backend
    runner_labels_frontend = var.runner_labels_frontend
  })

  # Forzar re-subida cuando el contenido del script cambia
  etag = md5(templatefile(local.user_data_template_path, {
    db_password            = var.db_password
    admin_seed_email       = var.admin_seed_email
    admin_seed_password    = var.admin_seed_password
    domain_name            = var.domain_name
    certbot_email          = var.certbot_email
    github_pat             = var.github_pat
    github_repo            = var.github_repo
    github_repo_frontend   = var.github_repo_frontend
    cloudwatch_log_group   = var.cloudwatch_log_group
    spring_profile         = var.spring_profile
    jwt_expiration_ms      = var.jwt_expiration_ms
    bucket_docs_name       = var.bucket_docs_name
    bucket_backups_name    = var.bucket_backups_name
    aws_region             = var.aws_region
    pg_remote_access       = var.pg_remote_access
    runner_name_backend    = var.runner_name_backend
    runner_name_frontend   = var.runner_name_frontend
    runner_labels_backend  = var.runner_labels_backend
    runner_labels_frontend = var.runner_labels_frontend
  }))

  tags = merge(local.common_tags, { Name = "docurural-${var.env}-user-data-script" })
}

# ── Key Pair ──────────────────────────────────────────────────────────────────

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = file(var.ssh_public_key_path)

  tags = local.common_tags
}

# ── Security Group ────────────────────────────────────────────────────────────

resource "aws_security_group" "this" {
  name        = "docurural-${var.env}-sg"
  description = "DocuRural - entorno ${var.env}"

  # HTTP — redirect a HTTPS (Certbot lo gestiona)
  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS — acceso público al frontend y la API
  ingress {
    description = "HTTPS publico"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH — solo desde la IP del administrador
  ingress {
    description = "SSH administrador"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  # PostgreSQL — SOLO en QA si se especifican IPs de QA (spec §3.1)
  # En PROD qa_ips = [] → este bloque no se crea → puerto 5432 cerrado
  dynamic "ingress" {
    for_each = length(var.qa_ips) > 0 ? [1] : []
    content {
      description = "PostgreSQL QA - acceso remoto PgAdmin"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = var.qa_ips
    }
  }

  # Salida — todo permitido (actualizaciones, S3, SSM, CloudWatch, GitHub)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "docurural-${var.env}-sg" })
}

# ── Instancia EC2 ─────────────────────────────────────────────────────────────

resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.this.id]
  iam_instance_profile   = var.iam_instance_profile

  # Bootstrap mínimo (~10 líneas): instala AWS CLI y descarga el user_data.sh real desde S3.
  # Esto evita el límite de 16 KB del campo user_data de EC2.
  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y curl unzip
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws
    aws s3 cp s3://${var.scripts_bucket_name}/user_data.sh /tmp/user_data.sh
    chmod +x /tmp/user_data.sh
    bash /tmp/user_data.sh
  EOF

  # No recrear la instancia si el script en S3 cambia (el runner de CI/CD hace el deploy)
  user_data_replace_on_change = false

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.ebs_size
    delete_on_termination = true
  }

  # La instancia depende del script en S3 — debe existir antes de arrancar
  depends_on = [aws_s3_object.user_data_script]

  tags = merge(local.common_tags, { Name = "docurural-${var.env}" })
}

# ── Elastic IP ────────────────────────────────────────────────────────────────

resource "aws_eip" "this" {
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "docurural-${var.env}-eip" })
}

resource "aws_eip_association" "this" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}
