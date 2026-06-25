# EC2 Module: Compute instances
# Uses Terraform AWS provider (not a public module, custom)

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Security group for EC2
resource "aws_security_group" "ec2" {
  name        = "${var.instance_name}-sg"
  description = "Security group for ${var.instance_name}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # SSH from anywhere (restrict in production)
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTP
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTPS
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # All outbound
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }
}

# EC2 Instances
resource "aws_instance" "ec2" {
  count                = var.instance_count
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  associate_public_ip_address = true

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = true
  }

  monitoring                  = var.enable_monitoring
  disable_api_termination     = false  # Allow termination in dev/staging
  iam_instance_profile        = null  # Add IAM role if needed

  tags = {
    Name        = "${var.instance_name}-${count.index + 1}"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [ami]  # Prevent rebuild on AMI updates
  }
}

# CloudWatch alarm for instance health (optional)
resource "aws_cloudwatch_metric_alarm" "instance_health" {
  count               = var.enable_monitoring ? var.instance_count : 0
  alarm_name          = "${var.instance_name}-${count.index + 1}-health"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = []  # Add SNS topic for notifications

  dimensions = {
    InstanceId = aws_instance.ec2[count.index].id
  }
}
