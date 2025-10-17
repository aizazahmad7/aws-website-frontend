data "aws_caller_identity" "me" {}

# ---------------------------
# S3 (private bucket for site)
# ---------------------------
resource "aws_s3_bucket" "site" {
  bucket        = var.bucket_name
  force_destroy = true
  tags = {
    Project = var.project_name
  }
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
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# ---------------------------
# CloudFront (with OAC)
# ---------------------------
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "oac-${var.bucket_name}"
  description                       = "Access control for ${var.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  s3_origin_domain = "${aws_s3_bucket.site.bucket}.s3.${var.region}.amazonaws.com"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_200"

  origin {
    domain_name              = local.s3_origin_domain
    origin_id                = "s3-${var.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    # IMPORTANT: Do not include s3_origin_config/custom_origin_config when using origin_access_control_id.
  }

  default_cache_behavior {
    target_origin_id       = "s3-${var.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Project = var.project_name
  }
}

# -----------------------------------------
# Bucket policy: allow ONLY this CF distro
# -----------------------------------------
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid     = "AllowCloudFrontOACRead"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    resources = [
      "${aws_s3_bucket.site.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values = [
        "arn:aws:cloudfront::${data.aws_caller_identity.me.account_id}:distribution/${aws_cloudfront_distribution.cdn.id}"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# -----------------------------------------
# GitHub OIDC role (Actions deploy)
# -----------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.deploy_branch}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "${var.project_name}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

data "aws_iam_policy_document" "deploy_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.site.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }

  statement {
    effect  = "Allow"
    actions = ["cloudfront:CreateInvalidation"]
    resources = [
      "arn:aws:cloudfront::${data.aws_caller_identity.me.account_id}:distribution/${aws_cloudfront_distribution.cdn.id}"
    ]
  }
}

resource "aws_iam_policy" "deploy_policy" {
  name   = "${var.project_name}-deploy-policy"
  policy = data.aws_iam_policy_document.deploy_policy.json
}

resource "aws_iam_role_policy_attachment" "deploy_attach" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = aws_iam_policy.deploy_policy.arn
}
