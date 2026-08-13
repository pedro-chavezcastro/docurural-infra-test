################################################################################
# DocuRural — Módulo GitHub Webhook Relay — outputs.tf
################################################################################

output "function_url" {
  description = "Function URL pública del Lambda — usar como Payload URL al registrar el webhook en la organización"
  value       = aws_lambda_function_url.relay.function_url
}

output "function_name" {
  description = "Nombre de la función Lambda"
  value       = aws_lambda_function.relay.function_name
}

output "function_arn" {
  description = "ARN de la función Lambda"
  value       = aws_lambda_function.relay.arn
}

output "log_group_name" {
  description = "Log group de CloudWatch del Lambda"
  value       = aws_cloudwatch_log_group.relay.name
}

output "role_arn" {
  description = "ARN del role de ejecución del Lambda"
  value       = aws_iam_role.relay.arn
}
