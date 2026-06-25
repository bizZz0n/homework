output "instance_ids" {
  value       = aws_instance.ec2[*].id
  description = "EC2 instance IDs"
}

output "instance_public_ips" {
  value       = aws_instance.ec2[*].public_ip
  description = "Public IP addresses"
}

output "instance_private_ips" {
  value       = aws_instance.ec2[*].private_ip
  description = "Private IP addresses"
}

output "security_group_id" {
  value       = aws_security_group.ec2.id
  description = "Security group ID"
}

output "instance_details" {
  value = {
    instance_ids       = aws_instance.ec2[*].id
    public_ips         = aws_instance.ec2[*].public_ip
    private_ips        = aws_instance.ec2[*].private_ip
    security_group_id  = aws_security_group.ec2.id
  }
  description = "Instance summary for downstream resources"
}
