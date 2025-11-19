variable "gh_owner"  { description = "aizazahmad7" }
variable "gh_repo"   { description = "aws-website-frontend" }
variable "gh_branch" { description = "master" }

# (If you already have this OIDC provider in your account, you can reference it via a data source instead)
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    # GitHub OIDC root CA thumbprint (current as of 2025; update if GitHub rotates)
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

# Role GitHub Actions will assume
resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsOIDCRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sts:AssumeRoleWithWebIdentity",
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      },
      Condition = {
        "StringEquals" = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub" = "repo:${var.gh_owner}/${var.gh_repo}:ref:refs/heads/${var.gh_branch}"
        }
      }
    }]
  })
}

# Attach the permissions your workflow needs (example: allow deploy via Lambda, APIGW, S3, etc.)
# Replace with least-privilege policies you require.
resource "aws_iam_policy" "gha_deploy_policy" {
  name        = "GitHubActionsDeployPolicy"
  description = "Permissions for GitHub Actions CI/CD"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["lambda:*"], Resource = "*" },
      { Effect = "Allow", Action = ["apigateway:*","execute-api:*"], Resource = "*" },
      { Effect = "Allow", Action = ["iam:PassRole"], Resource = "*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "gha_attach" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.gha_deploy_policy.arn
}
