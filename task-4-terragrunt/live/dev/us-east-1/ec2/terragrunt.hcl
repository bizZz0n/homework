# EC2 Component Configuration
# Depends on VPC (via dependency block)

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/ec2"
}

# Dependency: EC2 needs VPC ID from upstream component
dependency "vpc" {
  config_path = "../vpc"

  # Mock outputs for when vpc isn't deployed yet
  mock_outputs = {
    vpc_id      = "vpc-mock-12345"
    public_subnets = ["subnet-mock-1", "subnet-mock-2"]
  }
}

# EC2-specific inputs
inputs = {
  instance_name  = "dev-bastion-us-east-1"
  instance_type  = "t3.micro"
  instance_count = 1
  aws_region     = "us-east-1"

  # Fetch VPC outputs (automatic)
  vpc_id         = dependency.vpc.outputs.vpc_id
  subnet_id      = dependency.vpc.outputs.public_subnets[0]

  # Dev-specific settings
  enable_monitoring = false
  root_volume_size  = 20
  root_volume_type  = "gp2"
}
