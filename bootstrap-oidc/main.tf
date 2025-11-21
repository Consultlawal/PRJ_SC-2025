provider "aws" {
  region = var.region
}

# --- Variables ---
variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "github_owner" {
  description = "The GitHub organization or username (e.g., Consultlawal)"
  type        = string
  default     = "Consultlawal"
}

variable "github_repo_name" {
  description = "The GitHub repository name (e.g., PRJ_SC-2025)"
  type        = string
  default     = "PRJ_SC-2025"
}

variable "github_branch" {
  description = "The GitHub branch to allow role assumption from"
  type        = string
  default     = "main"
}


# --- OIDC Provider for GitHub Actions ---
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  # Common thumbprint for GitHub's OIDC provider.
  # This may need to be updated periodically if GitHub changes its certificate.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# --- IAM Policy Document for Trust Relationship (Assume Role Policy) ---
data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.github.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${replace(aws_iam_openid_connect_provider.github.url, "https://", "")}:sub"
      # Ensures only runs from your specific repo/branch can assume this role
      values = ["repo:${var.github_owner}/${var.github_repo_name}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

# --- IAM Role for GitHub Actions (The Role your CI/CD will assume) ---
resource "aws_iam_role" "github_actions_role" {
  # Naming convention fix: avoids the "/" character using only the repo name
  name               = "${var.github_repo_name}-github-actions-eks-role"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
  description        = "IAM Role for GitHub Actions to deploy and manage EKS cluster."
}

# --- IAM Policy Document for Permissions (The permissions attached to the role) ---
data "aws_iam_policy_document" "github_actions_permissions" {
  # Permission for EKS Cluster Management
  statement {
    sid    = "EKSReadWrite"
    effect = "Allow"
    actions = [
      "eks:*", # Grants all EKS actions for simplicity in this project
    ]
    resources = ["*"]
  }

  # Permission for EC2/ASG (Needed for Node Groups and Load Balancer operations)
  statement {
    sid    = "EC2AndASG"
    effect = "Allow"
    actions = [
      "ec2:*",
      "autoscaling:*"
    ]
    resources = ["*"]
  }
  
  # Permission for Route 53 (CRITICAL for ExternalDNS)
  statement {
    sid = "Route53Access"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
      "route53:GetHostedZone"
    ]
    resources = ["*"] 
  }

  # Permission for IAM (Needed to create/manage IRSA roles, service accounts, and PassRole)
  statement {
    sid    = "IAMReadWriteForEKS"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DetachRolePolicy",
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:PassRole", # CRITICAL: Allows EKS and services to assume the IRSA roles
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile"
    ]
    resources = ["*"]
  }

  # Permission for Terraform Backend S3/DynamoDB State Management
  statement {
    sid    = "S3AndDynamoDBAccess" 
    effect = "Allow"
    actions = [
      "s3:*", # Allows S3 state management and artifact storage
      "dynamodb:*" # Allows DynamoDB state locking
    ]
    resources = ["*"] # Best practice is to restrict this to your specific bucket/table ARNs
  }
}

# --- Attach Policy to Role ---
resource "aws_iam_policy" "github_actions_permissions_policy" {
  # Naming convention fix: avoids the "/" character using only the repo name
  name        = "${var.github_repo_name}-github-actions-eks-policy"
  description = "Policy for GitHub Actions to manage EKS and related resources."
  policy      = data.aws_iam_policy_document.github_actions_permissions.json
}

resource "aws_iam_role_policy_attachment" "github_actions_attach" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.github_actions_permissions_policy.arn
}

# --- Outputs ---
output "github_actions_role_arn" {
  description = "The ARN of the IAM role for GitHub Actions. Use this for your GitHub Secret GH_ACTIONS_ROLE_ARN."
  value       = aws_iam_role.github_actions_role.arn
}

output "github_oidc_provider_arn" {
  description = "The ARN of the OIDC provider for GitHub Actions."
  value       = aws_iam_openid_connect_provider.github.arn
}