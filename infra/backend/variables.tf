variable "project_name" { default = "aws-website-frontend" }
variable "env"          { default = "prod" }

# Use a Bedrock-supported region you’ve enabled (common: us-east-1)
variable "aws_region"     { default = "us-east-1" }
variable "bedrock_region" { default = "us-east-1" }

# Your CloudFront domain later (for CORS). For now you can leave "*".
variable "frontend_origin" { default = "*" }

variable "lambda_memory_mb" { default = 1024 }
variable "lambda_timeout_s" { default = 30 }
