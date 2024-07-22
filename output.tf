output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.netspi_vpc.id
}

output "subnet_id" {
  description = "The ID of the Subnet"
  value       = aws_subnet.netspi_subnet.id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.netspi_s3.arn
}

output "efs_id" {
  description = "The ID of the EFS"
  value       = aws_efs_file_system.netspi_efs.id
}

output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.netspi_ec2.id
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.netspi_sg.id
}