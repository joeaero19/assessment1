########## Setting your AWS account credentials and region ##########
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

########## Creating s3 backet to state terraform state file remotely ##########
#terraform {
#  backend "s3" {
#    bucket  = "terraform-state-bucket"
#    encrypt = true
#    key     = "terraform-deployment-state"
#    region  = "us-east-1"
#}

########## Network_component1: Creating VPC and all Networking Configurations ##########
resource "aws_vpc" "my-assessment-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "${var.app_name}-vpc"
    Environment = var.app_environment
  }
}

########## Network_component2: Creating Internet gateway to route traffic through the internet for the public subnet resources ##########
resource "aws_internet_gateway" "my-assessment-igw" {
  vpc_id = aws_vpc.my-assessment-vpc.id
  tags = {
    Name        = "${var.app_name}-igw"
    Environment = var.app_environment
  }
}

########## Network_component3: Creating Private subnets for resources that does not need route to internet gateway for internet access ##########
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.my-assessment-vpc.id
  count             = length(var.private_subnets)
  cidr_block        = element(var.private_subnets, count.index)
  availability_zone = element(var.availability_zones, count.index)

tags = {
  Name        = "${var.app_name}-private-subnet-${count.index + 1}"
  Environment = var.app_environment
 }
}

########## Network_component5: Creating Private route table ##########
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.my-assessment-vpc.id

  tags = {
    Name        = "${var.app_name}-private-route-table"
    Environment = var.app_environment
  }
}

########## Network_component6: Creating private route table association ##########
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.public.id
}


########## Creating Elastic IP for Nat gateway ##########
resource "aws_eip" "elastic-ip-for-nat-gw" {
  vpc                       = true
  associate_with_private_ip = "10.0.0.5"
  depends_on                = [aws_internet_gateway.my-assessment-igw]
}

########## NAT gateway for private subnet resources ###########
resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.elastic-ip-for-nat-gw.id
  subnet_id     = element(aws_subnet.public.*.id, 0)
  depends_on    = [aws_eip.elastic-ip-for-nat-gw]
}
resource "aws_route" "private" {
  route_table_id         = aws_route_table.private.id
  nat_gateway_id         = aws_nat_gateway.nat-gw.id
  destination_cidr_block = "0.0.0.0/0"
}

########## Network_component4: Creating Public subnets for resources that does not need to be accessed from the internet. ##########
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.my-assessment-vpc.id
  cidr_block              = element(var.public_subnets, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  count                   = length(var.public_subnets)
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.app_name}-public-subnet-${count.index + 1}"
    Environment = var.app_environment
  }
}

########## Network_component5: Creating Public route table ##########
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.my-assessment-vpc.id

  tags = {
    Name        = "${var.app_name}-public-route-table"
    Environment = var.app_environment
  }
}

########## Network_component6: Creating Public route to the internet gateway ##########
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my-assessment-igw.id
}

########## Network_component7: Creating Public route table association ##########
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}
########## Required roles and policies ##########
resource "aws_iam_role" "ecs-host-role" {
  name               = "${var.app_name}-ecs_host_role"
  assume_role_policy = file("policies/ecs-role.json")
}

resource "aws_iam_role_policy" "ecs-instance-role-policy" {
  name   = "${var.app_name}-ecs_instance_role_policy"
  policy = file("policies/ecs-instance-role-policy.json")
  role   = aws_iam_role.ecs-host-role.id
}

resource "aws_iam_role" "ecs-service-role" {
  name               = "${var.app_name}-ecs_service_role"
  assume_role_policy = file("policies/ecs-role.json")
}

resource "aws_iam_role_policy" "ecs-service-role-policy" {
  name   = "${var.app_name}-ecs_service_role_policy"
  policy = file("policies/ecs-service-role-policy.json")
  role   = aws_iam_role.ecs-service-role.id
}

resource "aws_iam_instance_profile" "ecs" {
  name = "${var.app_name}-ecs_instance_profile"
  path = "/"
  role = aws_iam_role.ecs-host-role.name
}
########################################################

########## Creating Security groups ##########

########## Creating load balancer Security Group ##########
resource "aws_security_group" "load-balancer" {
  name        = "load_balancer_security_group"
  description = "Controls access to the ALB"
  vpc_id      = aws_vpc.my-assessment-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########### Creating ECS Security group ##########
resource "aws_security_group" "ecs" {
  name        = "ecs_security_group"
  description = "Allows inbound access from the ALB only"
  vpc_id      = aws_vpc.my-assessment-vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.load-balancer.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
##############################################################

########## Creating the Load balancer (ALB) ##########
resource "aws_alb" "application_load_balancer" {
  name               = "${var.app_name}-${var.app_environment}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public.*.id
  security_groups    = [aws_security_group.load-balancer.id]

  tags = {
    Name        = "${var.app_name}-alb"
    Environment = var.app_environment
  }
}

########## Creating a target group for the loadbalancer ##########
resource "aws_alb_target_group" "default-target-group" {
  name     = "${var.app_name}-${var.app_environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my-assessment-vpc.id

  health_check {
    path                = var.health_check_path
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    matcher             = "200"
  }
}

########## Listener (redirects traffic from the load balancer to the target group) ##########
resource "aws_alb_listener" "ecs-alb-http-listener" {
  load_balancer_arn = aws_alb.application_load_balancer.id
  port              = "80"
  protocol          = "HTTP"
  depends_on        = [aws_alb_target_group.default-target-group]

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.default-target-group.id
  }
}
################################################################################################
############ Creating cloudwatch log group for the ecs service logs ################
resource "aws_cloudwatch_log_group" "log-group" {
  name = "${var.app_name}-${var.app_environment}-logs"

  tags = {
    Application = var.app_name
    Environment = var.app_environment
  }
}

#####################################################################################################
########## Creating ECS cluster ##########
resource "aws_ecs_cluster" "my-assessment-cluster" {
  name = "${var.app_name}-${var.app_environment}-cluster"
}

######## Find the most recent ECS optimized ami for the launch configuration############
data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name = "name"
    values = [
      "amzn2-ami-ecs-hvm-*-x86_64-ebs",
    ]
  }
  filter {
    name = "owner-alias"
    values = [
      "amazon",
    ]
  }
}


########### Creating launch configuration for autoscaling #########
resource "aws_launch_configuration" "ecs" {
  name                        = "${var.app_name}-${var.app_environment}-cluster"
  image_id                    = data.aws_ami.ecs_optimized.id
  instance_type               = var.instance_type
  security_groups             = [aws_security_group.ecs.id]
  iam_instance_profile        = aws_iam_instance_profile.ecs.name
  associate_public_ip_address = false
  user_data                   = templatefile("${path.module}/templates/user_data.tpl", {
                               ecs_cluster_name = aws_ecs_cluster.my-assessment-cluster.id

    })
}

data "template_file" "app" {
  template = file("templates/my_app.json.tpl")

vars = {
  docker_image_url_django = var.docker_image_url
  region                  = var.region
  rds_db_name             = var.rds_db_name
  rds_username            = var.rds_username
  rds_password            = var.rds_password
  rds_hostname            = aws_db_instance.my-assessment.address
 }
}

resource "aws_ecs_task_definition" "my-assessment-task" {
  family                = "my-app"
  container_definitions = data.template_file.app.rendered
}

resource "aws_ecs_service" "my-assessment-service" {
  name            = "${var.app_name}-${var.app_environment}-service"
  cluster         = aws_ecs_cluster.my-assessment-cluster.id
  task_definition = aws_ecs_task_definition.my-assessment-task.arn
  iam_role        = aws_iam_role.ecs-service-role.arn
  desired_count   = var.app_count
  depends_on      = [aws_alb_listener.ecs-alb-http-listener, aws_iam_role_policy.ecs-service-role-policy]

  load_balancer {
    target_group_arn = aws_alb_target_group.default-target-group.arn
    container_name   = "my-app"
    container_port   = 8000
  }
}

########## Autoscaling group ############
resource "aws_autoscaling_group" "ecs-cluster" {
  name                 = "${var.app_name}-${var.app_environment}_auto_scaling_group"
  min_size             = var.autoscale_min
  max_size             = var.autoscale_max
  desired_capacity     = var.autoscale_desired
  health_check_type    = "EC2"
  launch_configuration = aws_launch_configuration.ecs.name
  vpc_zone_identifier  = var.private_subnets

}

########## Route 53################
resource "aws_route53_zone" "main" {
  name  = var.fqdn_hosted_zone
}

resource "aws_route53_record" "record" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.fqdn_hosted_zone
  type    = "CNAME"
  ttl     = "10"
  records = [aws_alb.application_load_balancer.dns_name]
}
