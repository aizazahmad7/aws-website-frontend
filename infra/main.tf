############################
# main.tf (SPA on S3 + CF) #
############################

locals {
  tags = {
    App   = var.app_name
    Layer = "frontend"
  }
}
data "aws_caller_identity" "current" {}

# -------------------- S3 (existing bucket) --------------------
# IMPORTANT: This bucket ALREADY EXISTS and is owned by you.
# After saving this file, run once:
#   terraform import aws_s3_bucket.site aws-website-frontend-spa
resource "aws_s3_bucket" "site" {
  bucket        = "${var.app_name}-spa-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = local.tags

}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -------------------- CloudFront OAC + Cache Policy --------------------
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "${var.app_name}-oac"
  description                       = "OAC for ${var.app_name} SPA"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "frontend_spa" {
  name        = "${var.app_name}-spa-policy"
  default_ttl = 3600
  max_ttl     = 86400
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    headers_config {
      header_behavior = "none"
    }
    cookies_config {
      cookie_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

# -------------------- CloudFront Distribution (SPA) --------------------
resource "aws_cloudfront_distribution" "frontend_spa" {
  enabled             = true
  comment             = "${var.app_name} SPA"
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-spa"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-spa"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = aws_cloudfront_cache_policy.frontend_spa.id
  }

  # SPA router fallback: serve index.html for 404s so deep links work
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = local.tags
}

# -------------------- Bucket Policy (allow only this CF distro via OAC) --------------------
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowCloudFrontOAC",
        Effect    = "Allow",
        Principal = { Service = "cloudfront.amazonaws.com" },
        Action    = ["s3:GetObject"],
        Resource  = "${aws_s3_bucket.site.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" : aws_cloudfront_distribution.frontend_spa.arn
          }
        }
      }
    ]
  })
}
# ---------------------------------------------------------------------------
# GitHub Actions OIDC Deploy Role (for aizazahmad7/aws-website-frontend)
# ---------------------------------------------------------------------------


data "aws_iam_policy_document" "github_oidc_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # audience must be sts.amazonaws.com
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Allow only your repo on pushes to main, PRs, and (if used) environments
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:aizazahmad7/aws-website-frontend:ref:refs/heads/main",
        "repo:aizazahmad7/aws-website-frontend:pull_request",
        "repo:aizazahmad7/aws-website-frontend:environment:*"
      ]
    }
  }
}


resource "aws_iam_role" "github_deploy" {
  name               = "${var.app_name}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_trust.json
}

data "aws_iam_policy_document" "github_deploy_policy" {
  # Allow writing to S3 bucket
  statement {
    sid = "S3Write"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.site.arn,
      "${aws_s3_bucket.site.arn}/*"
    ]
  }

  # Allow CloudFront cache invalidation
  statement {
    sid       = "CFInvalidate"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_deploy_policy" {
  name   = "${var.app_name}-github-deploy"
  policy = data.aws_iam_policy_document.github_deploy_policy.json
}

resource "aws_iam_role_policy_attachment" "github_deploy_attach" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = aws_iam_policy.github_deploy_policy.arn
}

output "deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC deploys"
  value       = aws_iam_role.github_deploy.arn
}
# --- GitHub OIDC provider (needed once per account) ---
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  # GitHub's current root CA thumbprint
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}
