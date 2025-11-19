# API Gateway base URL (public HTTPS endpoint)
output "api_base_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

# Handy for finding the function in the console
output "lambda_function_name" {
  value = aws_lambda_function.api.function_name
}

# (optional) Full ARN
output "lambda_arn" {
  value = aws_lambda_function.api.arn
}
