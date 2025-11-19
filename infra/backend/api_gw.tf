# Assumes these already exist in api.tf:
# resource "aws_apigatewayv2_api" "http_api" { ... }
# resource "aws_lambda_function" "fastapi" { ... }
# resource "aws_lambda_permission" "apigw_invoke" { ... }  # if you already created it

data "aws_lambda_function" "fastapi" {
  function_name = "aws-website-frontend-prod-fastapi" # e.g., fastapi-handler
}

# 1) Integrate API → Lambda (proxy)
resource "aws_apigatewayv2_integration" "lambda_proxy" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = data.aws_lambda_function.fastapi.arn  # <-- changed
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}


# 2) Route all methods/paths to the Lambda
resource "aws_apigatewayv2_route" "any_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "$default" # catch-all (any method/any path)
  target    = "integrations/${aws_apigatewayv2_integration.lambda_proxy.id}"
}

# 3) Default stage with auto-deploy
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# 4) Output the base URL
output "api_invoke_url" {
  value       = aws_apigatewayv2_api.http_api.api_endpoint
  description = "Base URL of your HTTP API (use with any path you defined in FastAPI)."
}
