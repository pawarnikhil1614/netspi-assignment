provider "aws" {
  region = var.aws_region
}

data "aws_eip" "my_ip" {
  public_ip = var.eip_allocation_id
  }

# VPC
resource "aws_vpc" "netspi_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "netspi_vpc"
  }
}

# Subnet
resource "aws_subnet" "netspi_subnet" {
  vpc_id            = aws_vpc.netspi_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.aws_availability_zone

  tags = {
    Name = "netspi_subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "netspi_gw" {
  vpc_id = aws_vpc.netspi_vpc.id

  tags = {
    Name = "netspi_igw"
  }
}

# Route Table
resource "aws_route_table" "netspi_rt" {
  vpc_id = aws_vpc.netspi_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.netspi_gw.id
  }

  tags = {
    Name = "netspi_vpc_route_table"
  }
}

resource "aws_route_table_association" "netspi_rt_assoc" {
  subnet_id      = aws_subnet.netspi_subnet.id
  route_table_id = aws_route_table.netspi_rt.id
}

# Security Group
resource "aws_security_group" "netspi_sg" {
  vpc_id = aws_vpc.netspi_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "netspi_vpc_security_group"
  }
}

# S3 bucket with private access permission
resource "aws_s3_bucket" "netspi_s3" {
  bucket = var.s3_bucket_name

  tags = {
    Name = "netspi_s3_bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "netspi_s3_controls" {
  bucket = aws_s3_bucket.netspi_s3.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "acl" {
  depends_on = [aws_s3_bucket_ownership_controls.netspi_s3_controls]
  bucket     = aws_s3_bucket.netspi_s3.id
  acl        = "private"
}

resource "aws_s3_bucket_policy" "my_bucket_policy" {
  bucket = aws_s3_bucket.netspi_s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "${aws_s3_bucket.netspi_s3.arn}",
          "${aws_s3_bucket.netspi_s3.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "my_bucket_public_access_block" {
  bucket = aws_s3_bucket.netspi_s3.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# EFS
resource "aws_efs_file_system" "netspi_efs" {
  tags = {
    Name = "netspi_efs"
  }
}

resource "aws_efs_mount_target" "netspi_efs_tgt" {
  file_system_id  = aws_efs_file_system.netspi_efs.id
  subnet_id       = aws_subnet.netspi_subnet.id
  security_groups = [aws_security_group.netspi_sg.id]
}

# IAM Role
resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ec2_role"
  }
}

# IAM Policy
resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })

}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.id
}

resource "tls_private_key" "netspi_tls" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "netspi_key_pair" {
  key_name   = "netspi-key-pair" # Change to your desired key pair name
  public_key = tls_private_key.netspi_tls.public_key_openssh
}

# EC2 Instance
resource "aws_instance" "netspi_ec2" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  subnet_id            = aws_subnet.netspi_subnet.id
  security_groups      = [aws_security_group.netspi_sg.id]
  key_name             = aws_key_pair.netspi_key_pair.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
              sudo systemctl start amazon-ssm-agent
              yum install -y amazon-efs-utils
              mkdir -p /data/test
              mount -t efs -o tls ${aws_efs_file_system.netspi_efs.id}:/ /data/test
              EOF

  tags = {
    Name = "netspi_ec2_instance"
  }
}

# Assign Elastic IP
resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.netspi_ec2.id
  allocation_id = data.aws_eip.my_ip.id
}

