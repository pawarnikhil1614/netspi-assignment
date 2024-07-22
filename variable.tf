variable "aws_region" {
  description = "The AWS region to deploy the resources."
  type        = string
  default     = "us-east-1"
}

variable "aws_availability_zone" {
  description = "The AWS availability zone to deploy the subnet."
  type        = string
  default     = "us-east-1a"
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket."
  type        = string
  default     = "netspi-terraform-bucket"
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance."
  type        = string
  default     = "ami-01fccab91b456acc2"
}

variable "instance_type" {
  description = "The type of instance to deploy."
  type        = string
  default     = "t2.micro"
}

variable "eip_allocation_id" {
  description = "The allocation ID of the pre-provisioned Elastic IP."
  type        = string
  default     = "50.16.94.190"
}
