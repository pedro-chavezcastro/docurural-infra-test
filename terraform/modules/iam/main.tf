################################################################################
# DocuRural — Módulo IAM
# Role EC2 con permisos mínimos (principio de mínimo privilegio, spec §5.2 y §10.5):
#   - S3: docs + backups (full CRUD) + scripts (solo lectura para descargar user_data)
#   - CloudWatch Logs: CreateLogGroup, CreateLogStream, PutLogEvents
#   - SSM Parameter Store: GetParameter sobre /docurural/<env>/*
################################################################################

resource "aws_iam_role" "ec2_role" {
  name = "docurural-${var.env}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "docurural-${var.env}-ec2-role"
    Environment = var.env
    Project     = "DocuRural"
    ManagedBy   = "Terraform"
  }
}

# AmazonSSMManagedInstanceCore — permite Session Manager y patch management (spec §5.1)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Política inline de mínimo privilegio
resource "aws_iam_role_policy" "minimal_policy" {
  name = "docurural-${var.env}-minimal-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 — documentos y backups (lectura, escritura, borrado)
      {
        Sid    = "S3DocsBackups"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.bucket_docs_arn,
          "${var.bucket_docs_arn}/*",
          var.bucket_backups_arn,
          "${var.bucket_backups_arn}/*"
        ]
      },
      # S3 — bucket de scripts (solo GetObject para descargar el user_data al arrancar)
      {
        Sid      = "S3ScriptsReadOnly"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${var.bucket_scripts_arn}/*"
      },
      # CloudWatch Logs — enviar logs de la aplicación
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:${var.log_group_name}:*"
      },
      # SSM Parameter Store — solo leer los parámetros de este entorno
      {
        Sid    = "SSMParameterStore"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/docurural/${var.env}/*"
      }
    ]
  })
}

# Instance profile — vincula el role IAM a la instancia EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "docurural-${var.env}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name        = "docurural-${var.env}-ec2-profile"
    Environment = var.env
    Project     = "DocuRural"
    ManagedBy   = "Terraform"
  }
}
