# =============================================================================
# GITHUB ACTIONS OIDC IAM ROLE
# =============================================================================
#
# Creates the AWS IAM resources needed for GitHub Actions to build and push
# Docker images to Amazon ECR without storing long-lived credentials.
#
# How it works:
#   1. An OIDC Identity Provider is registered for GitHub Actions.
#   2. An IAM Role is created that GitHub Actions can assume via OIDC.
#   3. The trust policy restricts assumption to a specific GitHub repository
#      (and optionally a specific branch) to prevent other repos from using
#      this role.
#   4. An inline policy grants the minimum ECR permissions required to
#      authenticate, push, and pull images.
#
# After applying, set the following in your GitHub repository:
#   Secret : AWS_ROLE_ARN  → value of the `github_actions_role_arn` output
#   Variable: AWS_REGION   → value of var.aws_region (e.g. us-west-2)
# =============================================================================

# -----------------------------------------------------------------------------
# Data sources
# -----------------------------------------------------------------------------

# Fetch the TLS thumbprint for the GitHub OIDC provider endpoint.
# AWS requires this to validate the OIDC token issuer.
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

# -----------------------------------------------------------------------------
# GitHub Actions OIDC Identity Provider
# -----------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  # `sts.amazonaws.com` is the required audience for GitHub → AWS OIDC.
  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint of the GitHub OIDC TLS certificate.
  # Using a data source keeps this up-to-date automatically.
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = merge(local.common_tags, {
    Name = "github-actions-oidc-provider"
  })
}

# -----------------------------------------------------------------------------
# Trust policy — who can assume this role
# -----------------------------------------------------------------------------
#
# The `sub` condition locks assumption to a specific GitHub repository.
# The wildcard `:*` allows any branch/tag/PR ref within that repo.
# Tighten to `:ref:refs/heads/main` if you only want pushes to main to
# be able to assume the role (recommended for production).

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    sid     = "GitHubActionsOIDCTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restrict to your specific repository.
    # Format: repo:<org-or-user>/<repo>:<filter>
    # Examples:
    #   repo:my-org/retail-store-sample-app:*          (any ref in the repo)
    #   repo:my-org/retail-store-sample-app:ref:refs/heads/main  (main branch only)
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:*"]
    }
  }
}

# -----------------------------------------------------------------------------
# Permissions policy — what the role can do
# -----------------------------------------------------------------------------
#
# Principle of least privilege:
#   - GetAuthorizationToken must be `*` (no resource-level restriction in ECR).
#   - All other actions are scoped to the three per-service ECR repositories.

data "aws_iam_policy_document" "github_actions_ecr" {
  # ECR authentication — resource-level restrictions are not supported here.
  statement {
    sid    = "ECRAuthentication"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  # ECR image push/pull — scoped to the three retail-store service repositories.
  statement {
    sid    = "ECRRepositoryAccess"
    effect = "Allow"
    actions = [
      # Pull (needed for layer cache checks during push)
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      # Push
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/retail-store-sample-cart",
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/retail-store-sample-catalog",
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/retail-store-sample-orders",
    ]
  }

  # Allow the workflow to create repositories on first push if they don't exist.
  # Remove this statement if you pre-create the repositories manually.
  statement {
    sid    = "ECRCreateRepository"
    effect = "Allow"
    actions = [
      "ecr:CreateRepository",
      "ecr:DescribeRepositories",
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/retail-store-sample-*",
    ]
  }
}

# -----------------------------------------------------------------------------
# IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "github_actions" {
  name        = "github-actions-ecr-push-${var.environment}"
  description = "Assumed by GitHub Actions via OIDC to build and push images to ECR"

  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  # Short session duration — 1 hour is more than enough for a CI build.
  # Reduces the blast radius if a token is somehow misused.
  max_session_duration = 3600

  tags = merge(local.common_tags, {
    Name    = "github-actions-ecr-push-${var.environment}"
    Purpose = "GitHub Actions OIDC ECR push"
  })
}

# Attach the ECR permissions as an inline policy on the role.
resource "aws_iam_role_policy" "github_actions_ecr" {
  name   = "ecr-push-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_ecr.json
}

# -----------------------------------------------------------------------------
# ECR Repositories (one per service)
# -----------------------------------------------------------------------------
#
# Pre-creating the repositories is safer than relying on auto-creation:
# it lets you set encryption, image scanning, and lifecycle policies up front.

resource "aws_ecr_repository" "services" {
  for_each = toset(["cart", "catalog", "orders"])

  name                 = "retail-store-sample-${each.key}"
  image_tag_mutability = "MUTABLE" # `latest` tag is overwritten on each push

  # Enable server-side encryption with an AWS-managed key.
  encryption_configuration {
    encryption_type = "AES256"
  }

  # Scan images for OS and package vulnerabilities on every push.
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name    = "retail-store-sample-${each.key}"
    Service = each.key
  })
}

# Lifecycle policy — keep the last 10 tagged images and remove untagged layers
# older than 1 day to control storage costs.
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "sha"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
