# ---------------------------
# IAM ROLE FOR EKS CLUSTER
# ---------------------------
resource "aws_iam_role" "demo_cluster" {
  name = "terraform-eks-demo-cluster"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.demo_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.demo_cluster.name
}

# ---------------------------
# SECURITY GROUP FOR CONTROL PLANE
# ---------------------------
resource "aws_security_group" "eks_cluster_sg" {
  name        = "terraform-eks-demo-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.demo.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "eks_api_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster_sg.id
}

resource "aws_security_group_rule" "nodes_to_controlplane_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.demo.cidr_block]
  security_group_id = aws_security_group.eks_cluster_sg.id
  description       = "Allow nodes in VPC to reach EKS control plane"
}

# ---------------------------
# EKS CLUSTER
# ---------------------------
resource "aws_eks_cluster" "demo" {
  name     = var.cluster_name
  role_arn = aws_iam_role.demo_cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
    subnet_ids         = aws_subnet.demo[*].id
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
    aws_security_group_rule.nodes_to_controlplane_443
  ]
}

# ---------------------------
# OIDC PROVIDER FOR IRSA
# ---------------------------
data "tls_certificate" "eks_oidc" {
  url        = aws_eks_cluster.demo.identity[0].oidc[0].issuer
  depends_on = [aws_eks_cluster.demo]
}

resource "aws_iam_openid_connect_provider" "demo" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.demo.identity[0].oidc[0].issuer

  depends_on = [
    aws_eks_cluster.demo,
    data.tls_certificate.eks_oidc
  ]
}
