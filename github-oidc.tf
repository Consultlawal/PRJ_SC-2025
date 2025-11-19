############################################################
# GitHub OIDC Provider + IAM Role for GitHub Actions (OIDC)
#
# Usage:
#  - Set var.github_repo = "my-org/my-repo"
#  - Set var.allowed_ref to "refs/heads/main" (or "*" for any branch; or "refs/tags/*" for tags)
#  - Apply Terraform, then copy the output role_arn into
#    GitHub secret GITHUB_OIDC_ROLE_ARN
############################################################

variable "github_repo" {
  description = "GitHub repo in the form owner/repo (e.g. my-org/my-repo)"
  type        = string
  default     = "your-org/your-repo"
}

variable "allowed_ref" {
  description = "Allowed Git ref for OIDC tokens (example: refs/heads/main). Use '*' for all branches (less secure)."
  type        = string
  default     = "refs/heads/main"
}

# The well-known GitHub thumbprint (GitHub's CA)
locals {
  github_thumbprint = "6938fd4d98bab03faadb97b34396831e3780aea1"
}

# 1) OIDC Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [local.github_thumbprint]
}

# 2) IAM Role assumable by GitHub Actions via OIDC
# The assume_role_policy restricts by repo and ref (branch/tag).
data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringLike"
      # Restrict subject to the specific repository. token.actions.githubusercontent.com:sub is like:
      # "repo:<owner>/<repo>:ref:refs/heads/<branch>"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:${var.github_repo}:ref:${var.allowed_ref}"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_actions_role" {
  name               = replace("${var.github_repo}-github-actions-role", "/", "-")
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
  description        = "Role assumable by GitHub Actions (OIDC) for ${var.github_repo}"
  # Optionally add tags
  tags = {
    managed_by = "terraform"
    purpose    = "github-oidc"
  }
}

# -------------------------
# 3A) Quick (fast) option: attach AdministratorAccess
# -------------------------
# WARNING: AdministratorAccess is broad. Use only for quick setup/testing.
resource "aws_iam_role_policy_attachment" "attach_admin" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -------------------------
# 3B) Recommended: example minimal policy skeleton (comment out attach_admin if using this)
# -------------------------
# Example policy giving access to S3 (artifact bucket), EKS (cluster actions),
# and limited IAM / EC2 as needed by Terraform. This is a STARTING POINT — adjust per your infra.
data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid    = "S3ArtifactAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      aws_s3_bucket.ci_artifacts.arn,
      "${aws_s3_bucket.ci_artifacts.arn}/*"
    ]
  }

  statement {
    sid    = "EKSReadWrite"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:CreateCluster",
      "eks:DeleteCluster",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:CreateFargateProfile",
      "eks:CreateNodegroup",
      "eks:DeleteNodegroup",
      "eks:DescribeNodegroup",
      "eks:ListNodegroups"
    ]
    resources = ["*"] # Narrow this later to specific clusters ARNs if you know them
  }

  statement {
    sid    = "EC2AndASGForNodeGroups"
    effect = "Allow"
    actions = [
      "ec2:*",
      "autoscaling:*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAMRead"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:PassRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:AttachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListRolePolicies"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_actions_permissions_policy" {
  name        = replace("${var.github_repo}-github-actions-policy", "/", "-")
  description = "Starter permission policy for GitHub Actions for ${var.github_repo}"
  policy      = data.aws_iam_policy_document.github_actions_permissions.json
}

resource "aws_iam_role_policy_attachment" "github_attach_custom" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.github_actions_permissions_policy.arn
}

# NOTE: if you prefer the quick Admin option, comment out the custom policy attachment above
# and keep attach_admin. If you prefer the custom policy, remove or disable attach_admin resource.

# If you used aws_s3_bucket.ci_artifacts in your repo already, reference it; else comment out the S3 bits
# Example for that bucket (if you followed earlier suggestion)
resource "aws_s3_bucket" "ci_artifacts" {
  bucket = "${replace(var.github_repo, "/", "-")}-ci-artifacts-${random_id.bucket_suffix.hex}"
  acl    = "private"

  versioning {
    enabled = true
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 3
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_role.arn
}
