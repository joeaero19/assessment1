# core

variable "region" {
  description = "The AWS region to create resources in."
  default     = "us-east-1"
}

# networking
variable "aws_region" {
  default = "us-east-1"
}

variable "aws_access_key" {
  default = "your aws access key"
}

variable "aws_secret_key" {
  default = "your aws secret key"
}

variable "ecr_repo_name"{
default= "your_repo_name"
}

variable "private_subnets" {
  description = "CIDR Block for Public Subnet 1"
  default     = "10.0.1.0/24"
}
variable "public_subnets" {
  description = "CIDR Block for Public Subnet 2"
  default     = "10.0.2.0/24"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}


# load balancer

variable "health_check_path" {
  description = "Health check path for the default target group"
  default     = "/ping/"
}


# ecs

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  default     = "my-assessment"
}

variable "instance_type" {
  default = "t2.micro"
}
variable "docker_image_url" {
  description = "Docker image to run in the ECS cluster"
  default     = "<AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/my-app:latest"
}

variable "app_count" {
  description = "Number of Docker containers to run"
  default     = 2
}


# logs
variable "log_retention_in_days" {
  default = 30
}

# auto scaling
variable "autoscale_min" {
  description = "Minimum autoscale (number of EC2)"
  default     = "1"
}
variable "autoscale_max" {
  description = "Maximum autoscale (number of EC2)"
  default     = "7"
}
variable "autoscale_desired" {
  description = "Desired autoscale (number of EC2)"
  default     = "4"
}



#Route53
variable "fqdn_hosted_zone" {
  description = "fqdn_hosted_zone"
  default     = "myapp.com"
}



# rds

variable "rds_db_name" {
  description = "RDS database name"
  default     = "mydb"
}
variable "rds_username" {
  description = "RDS database username"
  default     = "foo"
}
variable "rds_password" {
  description = "RDS database password"
}
variable "rds_instance_class" {
  description = "RDS instance type"
  default     = "db.t2.micro"
}

#General
variable "app_name" {
  description = "general tag name"
  default     = "interview"
}

variable "app_environment" {
  description = "deployment environment"
  default     = "dev"
}
