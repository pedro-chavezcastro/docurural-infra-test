################################################################################
# DocuRural — Módulo GitHub Webhook Relay
# Lambda "tonto" entre el webhook de organización de GitHub (Projects v2) y el
# repo docurural-backend: verifica la firma HMAC, filtra ruido y reenvía un
# repository_dispatch (event_type: project-status-changed) con el node id del
# issue que cambió de Status.
#
# Toda la lógica de negocio (confirmar que el issue es el padre de la release
# y propagar el estado a sus sub-issues) vive en
# .github/scripts/update_project_status.py (modo cascade), disparado por
# .github/workflows/project-cascade.yml en docurural-backend. Este Lambda no
# sabe nada de releases ni de sub-issues.
#
# Expuesto vía Function URL con auth NONE: no hay forma de que GitHub firme
# requests con SigV4 de AWS, así que la Function URL queda públicamente
# invocable y la autenticidad la garantiza exclusivamente la verificación de
# la firma HMAC dentro del handler (src/index.mjs).
################################################################################

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/src/index.mjs"
  output_path = "${path.module}/build/function.zip"
}

# Role de ejecución del Lambda — permiso mínimo: escribir logs en CloudWatch.
resource "aws_iam_role" "relay" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name      = "${var.function_name}-role"
    Project   = "DocuRural"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.relay.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Log group explícito — sin esto Lambda lo crea igual al primer invoke, pero
# con retención infinita y fuera del estado de Terraform.
resource "aws_cloudwatch_log_group" "relay" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 30

  tags = {
    Name      = "/aws/lambda/${var.function_name}"
    Project   = "DocuRural"
    ManagedBy = "Terraform"
  }
}

resource "aws_lambda_function" "relay" {
  function_name = var.function_name
  role          = aws_iam_role.relay.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 15
  memory_size   = 128

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      GITHUB_WEBHOOK_SECRET = var.github_webhook_secret
      GITHUB_DISPATCH_TOKEN = var.github_dispatch_token
      TARGET_REPO           = var.target_repo
    }
  }

  depends_on = [aws_cloudwatch_log_group.relay]

  tags = {
    Name      = var.function_name
    Project   = "DocuRural"
    ManagedBy = "Terraform"
  }
}

resource "aws_lambda_function_url" "relay" {
  function_name      = aws_lambda_function.relay.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "function_url" {
  statement_id           = "FunctionURLAllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.relay.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

# Desde octubre 2025, además de lambda:InvokeFunctionUrl, AWS exige
# lambda:InvokeFunction en la política de recursos para que una Function URL
# con auth NONE sea invocable — sin este segundo statement, la Function URL
# responde 403 aunque el statement de arriba y el AuthType estén correctos.
# InvokedViaFunctionUrl restringe este permiso a invocaciones vía la URL,
# no vía otros métodos (consola, SDK, etc).
resource "aws_lambda_permission" "invoke_function" {
  statement_id             = "FunctionURLAllowPublicInvoke"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.relay.function_name
  principal                = "*"
  invoked_via_function_url = true
}
