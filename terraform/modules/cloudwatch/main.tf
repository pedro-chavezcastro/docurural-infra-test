################################################################################
# DocuRural — Módulo CloudWatch
# Log group de la aplicación + Budget billing alarm
# spec §13 (logs) y §13.2 / §14.2 de la spec Config QA/PROD (billing)
################################################################################

# Log group — retención 30 días (spec §13.1)
resource "aws_cloudwatch_log_group" "app" {
  name              = var.log_group_name
  retention_in_days = 30

  tags = {
    Name        = var.log_group_name
    Environment = var.env
    Project     = "DocuRural"
    ManagedBy   = "Terraform"
  }
}

# Budget mensual de costo — alerta al 80% del límite (spec §13.2 / §14.2)
# QA: $15 USD  |  PROD: $30 USD
resource "aws_budgets_budget" "monthly" {
  name         = "docurural-${var.env}-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}
