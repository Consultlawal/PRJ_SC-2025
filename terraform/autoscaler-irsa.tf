resource "aws_iam_role" "autoscaler" {
  name = "${var.cluster-name}-autoscaler-role"

  assume_role_policy = data.aws_iam_policy_document.autoscaler_assume.json
}

data "aws_iam_policy_document" "autoscaler_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "autoscaler_policy_attach" {
  role       = aws_iam_role.autoscaler.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}

output "autoscaler_iam_role_arn" {
  value = aws_iam_role.autoscaler.arn
}
