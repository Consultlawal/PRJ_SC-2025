# infra-artifacts.tf
resource "aws_s3_bucket" "ci_artifacts" {
  bucket = "${var.cluster-name}-ci-artifacts-${random_id.bucket_suffix.hex}"
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "expire-old-artifacts"
    enabled = true

    expiration {
      days = 365
    }
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# optional IAM user for CI (if not using OIDC)
resource "aws_iam_user" "github_actions_user" {
  name = "${var.cluster-name}-gh-actions"
  path = "/ci/"
}

resource "aws_iam_user_policy" "github_actions_s3" {
  name = "gh-actions-s3-upload"
  user = aws_iam_user.github_actions_user.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.ci_artifacts.arn,
          "${aws_s3_bucket.ci_artifacts.arn}/*"
        ]
      }
    ]
  })
}

output "ci_artifacts_bucket" {
  value = aws_s3_bucket.ci_artifacts.bucket
}
output "github_actions_user_access_key_create" {
  value = "Create access key in console for user ${aws_iam_user.github_actions_user.name} and store as GitHub secret if you don't use OIDC"
}
