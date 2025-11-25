# --- ALB Controller IRSA (corrected) ---

# Trust policy for the ALB controller service account using the IAM OIDC provider ARN
data "aws_iam_policy_document" "assume_role_alb" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.demo.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      # token.actions... not used here — for EKS OIDC the variable is <issuer-without-https>:sub
      variable = "${replace(aws_eks_cluster.demo.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster-name}-ALBController-Role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_alb.json

  depends_on = [
    aws_eks_cluster.demo,
    aws_iam_openid_connect_provider.demo
  ]
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach_managed" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancerControllerPolicy"
  # Ensure role and policy are both ready before attempting attachment
  depends_on = [
    aws_iam_role.alb_controller 
  ]
}
