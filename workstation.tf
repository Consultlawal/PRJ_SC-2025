###############################################
# 1. IAM Role for Workstation EC2
###############################################
resource "aws_iam_role" "workstation_role" {
  name = "${var.cluster-name}-workstation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "workstation_vpc_full_access" {
  role       = aws_iam_role.workstation_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}

resource "aws_iam_role_policy_attachment" "workstation_ec2_full_access" {
  role       = aws_iam_role.workstation_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "workstation_s3_full_access" {
  role       = aws_iam_role.workstation_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "workstation_profile" {
  name = "${var.cluster-name}-workstation-instance-profile"
  role = aws_iam_role.workstation_role.name
}

###############################################
# 1b. Security Group for Workstation (SSH open to all)
###############################################
resource "aws_security_group" "workstation_sg" {
  name   = "${var.cluster-name}-workstation-sg"
  vpc_id = aws_vpc.demo.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # SSH open to all (temporary)
    # cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"]  # only your IP (Terraform can fetch your public IP dynamically using a data "http" block. Once you confirm SSH access works, restrict the security group to only your IP for security.)
    # cidr_blocks      = ["${local.my_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster-name}-Workstation-SG"
  }
}


###############################################
# 2. Ubuntu EC2 Instance
###############################################
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-*"]
  }
}

resource "aws_instance" "workstation" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  # Use the existing key pair from eks-worker-nodes.tf
  key_name = aws_key_pair.public_key.key_name

  iam_instance_profile = aws_iam_instance_profile.workstation_profile.name

  subnet_id               = aws_subnet.demo[0].id
  vpc_security_group_ids  = [aws_security_group.workstation_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update && sudo apt upgrade -y

              # Install Terraform
              wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
              sudo unzip terraform_1.5.0_linux_amd64.zip -d /usr/local/bin/
              rm terraform_1.5.0_linux_amd64.zip

              # Install kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              chmod +x kubectl
              sudo mv kubectl /usr/local/bin/
              EOF

  tags = {
    Name = "${var.cluster-name}-Workstation"
  }
}

###############################################
# 3. Output
###############################################
output "workstation_public_ip" {
  value = aws_instance.workstation.public_ip
}

output "workstation_private_key_path" {
  value = local_file.private_key.filename
}
