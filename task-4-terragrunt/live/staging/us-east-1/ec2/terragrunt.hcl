# EC2 Component for Staging
# More instances, larger type for HA

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/ec2"
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id      = "vpc-mock-staging"
    public_subnets = ["subnet-mock-staging-1", "subnet-mock-staging-2"]
  }
}

inputs = {
  instance_name  = "staging-web-us-east-1"
  instance_type  = "t3.small"  # Staging has larger instances
  instance_count = 2  # HA: 2 instances
  aws_region     = "us-east-1"

  vpc_id         = dependency.vpc.outputs.vpc_id
  subnet_id      = dependency.vpc.outputs.public_subnets[0]

  enable_monitoring = true  # Monitor staging
  root_volume_size  = 50  # Larger disk
  root_volume_type  = "gp3"  # Better performance
}
