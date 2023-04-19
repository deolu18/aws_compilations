variable "ec2_name" {
  type    =string
  default = "zehe"
}

variable "bucket_name" {
  type    = string
  default = "zehewebsitee"
}

variable "api_name" {
  type    = string
  default = "api_lambda"
}

variable "rds_master_username" {
  type    = string
}

variable "rds_master_password" {
  type    = string
}

variable "userdata" {
  default     = ""
  description = "Extra commands to pass to userdata."
}

variable "ec2_create" {
  default     = false
  description = "Enable when cluster is only for ec2 creation"
}

variable "instance_volume_size" {
  default     = 30
}

variable "volume_type" {
  default     = "gp2"
  description = "The EBS volume type"
}

variable "security_group_ids" {
  type        = list(string)
  default     = []
  description = "Extra security groups for instances."
}

variable "public_subnet_cidrs" {
 type        = list(string)
 description = "Public Subnet CIDR values"
}

variable "private_subnet_cidrs" {
 type        = list(string)
 description = "Private Subnet CIDR values"
}

variable "azs" {
 type        = list(string)
 description = "Availability Zones"
}

variable "instance_tenancy" {
  type        = string
  description = "VPC tenancy"
}

variable "instance_type" {
  type        = string
  description = "type of ec2 instance"
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "ec2_sg_name" {
  description = "Name of the ec2 security group"
  type        = string
}

variable "rsa_bits" {
  description = "bits of private key"
  type        = number 
}

variable "algorithm" {
  description = "algorithm of rsa key"
  type        = string 
}

variable "key_name" {
  description = "key pair name"
  type        = string 
}

variable "asg_name" {
  description = "name of asg"
  type        = string 
}

variable "asg_min_size" {
  description = "min size of asg"
  type        = number 
}

variable "asg_max_size" {
  description = "max size of asg"
  type        = number 
}

variable "asg_desired" {
  description = "default size of asg"
  type        = number 
}

variable "health_check_grace_period" {
  description = "health check period of asg"
  type        = number 
}