# # --- Cluster Autoscaler IRSA (corrected) ---

# # 1. IAM Policy Document for Cluster Autoscaler permissions
# data "aws_iam_policy_document" "autoscaler_policy" {
#   statement {
#     effect    = "Allow"
#     actions   = [
#       "autoscaling:DescribeAutoScalingGroups",
#       "autoscaling:DescribeAutoScalingInstances",
#       "autoscaling:DescribeLaunchConfigurations",
#       "autoscaling:DescribeTags",
#       "autoscaling:SetDesiredCapacity",
#       "autoscaling:TerminateInstanceInAutoScalingGroup",
#       "ec2:DescribeLaunchTemplateVersions",
#       "ec2:DescribeInstances"
#     ]
#     resources = ["*"]
#   }
# }

# resource "aws_iam_policy" "cluster_autoscaler" {
#   name   = "${var.cluster-name}-ClusterAutoscaler-Policy"
#   policy = data.aws_iam_policy_document.autoscaler_policy.json
# }

# # 2. Assume role policy for the cluster-autoscaler service account
# data "aws_iam_policy_document" "autoscaler_assume" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Federated"
#       identifiers = [aws_iam_openid_connect_provider.demo.arn]
#     }

#     actions = ["sts:AssumeRoleWithWebIdentity"]

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(aws_eks_cluster.demo.identity[0].oidc[0].issuer, "https://", "")}:sub"
#       values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
#     }
#   }
# }

# resource "aws_iam_role" "cluster_autoscaler" {
#   name               = "${var.cluster-name}-ClusterAutoscaler-Role"
#   assume_role_policy = data.aws_iam_policy_document.autoscaler_assume.json

#   depends_on = [
#     aws_eks_cluster.demo,
#     aws_iam_openid_connect_provider.demo
#   ]
# }

# resource "aws_iam_role_policy_attachment" "cluster_autoscaler_attach" {
#   role       = aws_iam_role.cluster_autoscaler.name
#   policy_arn = aws_iam_policy.cluster_autoscaler.arn
# }


# --- Cluster Autoscaler IRSA ---

data "aws_iam_policy_document" "autoscaler_policy" {
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeInstances"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name   = "${var.cluster_name}-ClusterAutoscaler-Policy"
  policy = data.aws_iam_policy_document.autoscaler_policy.json
}

data "aws_iam_policy_document" "autoscaler_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.demo.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.demo.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  name               = "${var.cluster_name}-ClusterAutoscaler-Role"
  assume_role_policy = data.aws_iam_policy_document.autoscaler_assume.json

  depends_on = [
    aws_eks_cluster.demo,
    aws_iam_openid_connect_provider.demo
  ]
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_attach" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}
