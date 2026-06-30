variable "instance_name" {
  type        = string
  description = "Name of the EC2 instance"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Instance type (t3.micro, t3.small, etc.)"
}

variable "instance_count" {
  type        = number
  default     = 1
  description = "Number of instances to launch"

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC ID (from vpc module)"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for instance placement"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "environment" {
  type        = string
  description = "Environment (dev, staging, prod)"
}

variable "enable_monitoring" {
  type        = bool
  default     = false
  description = "Enable CloudWatch detailed monitoring"
}

variable "root_volume_size" {
  type        = number
  default     = 20
  description = "Root volume size in GB"
}

variable "root_volume_type" {
  type        = string
  default     = "gp2"
  description = "Root volume type (gp2, gp3, io1)"

  validation {
    condition     = contains(["gp2", "gp3", "io1"], var.root_volume_type)
    error_message = "Volume type must be gp2, gp3, or io1."
  }
}
