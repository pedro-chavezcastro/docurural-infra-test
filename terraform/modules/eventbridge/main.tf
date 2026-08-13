################################################################################
# DocuRural — Módulo EventBridge Scheduler
# ⚠  Solo instanciar en envs/prod — no aplica en QA.
#
# Apaga el EC2 a las 10 PM y lo enciende a las 6 AM (L–V), timezone America/Bogota.
# Ahorro estimado: ~$15.18 → ~$7.22 USD/mes (spec §4.3)
#
# ✅ Completamente gratuito: ~60 invocaciones/mes vs. límite gratuito de 14 millones.
################################################################################

# Role que EventBridge Scheduler usa para llamar a la API de EC2
resource "aws_iam_role" "scheduler_role" {
  name = "docurural-prod-eventbridge-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "docurural-prod-eventbridge-scheduler-role"
    Environment = "prod"
    Project     = "DocuRural"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "scheduler_ec2_policy" {
  name = "docurural-prod-scheduler-ec2-policy"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:StartInstances",
        "ec2:StopInstances"
      ]
      # Scope mínimo: solo la instancia de producción
      Resource = var.instance_arn
    }]
  })
}

# Apagado automático: 10 PM Colombia (22:00), lunes a viernes (spec §15.1)
resource "aws_scheduler_schedule" "apagado_nocturno" {
  name       = "docurural-apagado-nocturno"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(0 22 ? * MON-FRI *)"
  schedule_expression_timezone = "America/Bogota"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      InstanceIds = [var.instance_id]
    })
  }
}

# Encendido automático: 6 AM Colombia (06:00), lunes a viernes (spec §15.1)
resource "aws_scheduler_schedule" "encendido_matutino" {
  name       = "docurural-encendido-matutino"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(0 6 ? * MON-FRI *)"
  schedule_expression_timezone = "America/Bogota"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      InstanceIds = [var.instance_id]
    })
  }
}
