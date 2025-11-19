locals {
  lambda_name = "${var.project_name}-${var.env}-fastapi"
  artifact    = "${path.module}/build/backend.zip"  # we will build this zip next
}

resource "aws_lambda_function" "api" {
  function_name = local.lambda_name
  architectures = ["arm64"]
  role          = aws_iam_role.lambda_role.arn

  # IMPORTANT: entrypoint to Mangum handler inside your code
  handler       = "backend.app.main.handler"
  runtime       = "python3.12"

  filename         = local.artifact
  source_code_hash = filebase64sha256(local.artifact)

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_s

  environment {
    variables = {
      FRONTEND_ORIGIN = var.frontend_origin
      BEDROCK_REGION  = var.bedrock_region
    }
  }
}
