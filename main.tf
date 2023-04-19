# ------------------Provider details---------------------------------
provider "aws" {
  region = var.region
}

# ------------------VPC---------------------------------
resource "aws_vpc" "ec2" {

  cidr_block       = "10.0.0.0/16"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"
  instance_tenancy = var.instance_tenancy
}

# ------------------SG---------------------------------
resource "aws_security_group" "asg_sg" {
  name        = var.ec2_sg_name
  description = "SG for EC2"
  vpc_id      = aws_vpc.ec2.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "vpc_ssh" {

  description       = "enable all inbound traffic from port 80 and enable all outbound traffic to Vpc"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.asg_sg.id
}

# ------------------Subnets---------------------------------
resource "aws_subnet" "public_subnets" {
 count                   = length(var.public_subnet_cidrs)
 vpc_id                  = aws_vpc.ec2.id
 cidr_block              = element(var.public_subnet_cidrs, count.index)
 availability_zone       = element(var.azs, count.index)
 map_public_ip_on_launch = true
 
 tags = {
   Name = "Public Subnet ${count.index + 1}"
 }
}
 
resource "aws_subnet" "private_subnets" {
 count             = length(var.private_subnet_cidrs)
 vpc_id            = aws_vpc.ec2.id
 cidr_block        = element(var.private_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)
 
 tags = {
   Name = "Private Subnet ${count.index + 1}"
 }
}

# ------------------IGW-----------------------------------------
resource "aws_internet_gateway" "ec2gw" {
 vpc_id = aws_vpc.ec2.id
 
 tags = {
   Name = "Zehe VPC IG"
 }
}

# ------------------Route Tables---------------------------------
resource "aws_route_table" "public_rt" {
 vpc_id = aws_vpc.ec2.id
 
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.ec2gw.id
 }
}

resource "aws_route_table_association" "public_subnet_association" {
 count          = 1
 subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
 route_table_id = aws_route_table.public_rt.id
}

# ------------------Private Key---------------------------------
resource "tls_private_key" "algorithm" {
  algorithm = var.algorithm
  rsa_bits  = var.rsa_bits
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.algorithm.public_key_openssh
}

# ------------------User Data---------------------------------
data "template_file" "userdata" {
  template = file("${path.module}/userdata.tpl")
}

# ------------------Launch Template---------------------------------
resource "aws_launch_template" "ec2" {
  count         =  1
  name_prefix   = "ec2-${var.ec2_name}"
  image_id      = data.aws_ami.amzn.image_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = var.instance_volume_size
      encrypted   = true
      volume_type = var.volume_type
    }
  }
  
  key_name               = aws_key_pair.generated_key.key_name

  user_data = base64encode(data.template_file.userdata.rendered)

  lifecycle {
    create_before_destroy = false
  }

  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.asg_sg.id]
  }

  placement {
    availability_zone = element(var.azs, count.index)
  }
}

# ------------------ASG---------------------------------
resource "aws_autoscaling_group" "ec2_zehe" {

  count                     = 1           
  name                      = var.asg_name
  max_size                  = var.asg_max_size
  min_size                  = var.asg_min_size
  health_check_grace_period = var.health_check_grace_period
  health_check_type         = "ELB"
  desired_capacity          = var.asg_desired
  force_delete              = true
  launch_template {
    id      = aws_launch_template.ec2[count.index].id
    version = "$Latest"
  }

  # wait_for_elb_wait_for_elb_capacity = true
  vpc_zone_identifier       = [aws_subnet.public_subnets[count.index].id]

#   initial_lifecycle_hook {
#     name                 = "zehe"
#     default_result       = "CONTINUE"
#     heartbeat_timeout    = 2000
#     lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
#   }
}

# ----------------------Access Logs Bucket---------------------------------
# resource "aws_s3_bucket" "zehe_access_logs" {
#   bucket = "zehe-access-logs-bucket"
# }

# ----------------------Load Balancer---------------------------------
resource "aws_lb" "zehe_lb" {
 count                     = 1           

 name            = "zehe-app-lb"
 internal        = false
 security_groups = [aws_security_group.lb_sg.id]
 subnets         = [aws_subnet.public_subnets[0].id, aws_subnet.public_subnets[1].id, aws_subnet.public_subnets[2].id]
#  access_logs {
#    bucket  = aws_s3_bucket.zehe_access_logs.bucket
#    enabled = true
#  }
}

resource "aws_lb_target_group" "this" {
  # depends_on  = [ aws_lb.zehe_lb ]
  name        = "zehe-target-group-80"
  port        = 80
  target_type = "instance"
  protocol    = "HTTP"
  vpc_id      = aws_vpc.ec2.id

  health_check {
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = "20"
    timeout             = "5"
    matcher             = "200-499"
  }
}

resource "aws_lb_listener" "zehe_alb_listener" {
  count             = 1
  load_balancer_arn = aws_lb.zehe_lb[count.index].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.this.arn
    type             = "forward"
  }
}

resource "aws_security_group" "lb_sg" {
  name = "lb_sg"
  description = "Security Group for ALB"
  vpc_id      = aws_vpc.ec2.id

  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
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

# ----------------------Autoscaling Attachement---------------------------------
resource "aws_autoscaling_attachment" "target" {
  count                  = 1
  autoscaling_group_name = aws_autoscaling_group.ec2_zehe[count.index].name
  lb_target_group_arn   = aws_lb_target_group.this.arn
}

# ----------------------EC2 Instance Profile---------------------------------
resource "aws_iam_instance_profile" "ec2" {
  name  = "ec2-${var.ec2_name}-${data.aws_region.current.name}"
  role  = aws_iam_role.ec2.name
}

resource "aws_iam_role" "ec2" {
  name  = "ec2-${var.ec2_name}-${data.aws_region.current.name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ec2" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# ----------------------EC2 Cloudwatch Logs---------------------------------
resource "aws_cloudwatch_log_group" "zehe_website_logs" {
  name = "zehe"

  tags = {
    Environment = "dev"
    Application = "zehe_website"
  }
}

# # -----------DynamoDB-----------------------------
resource "aws_dynamodb_table" "enquiry_image_table" {
  name           = "enquiry_image_table"
  billing_mode   = "PROVISIONED"
  read_capacity  = 100
  write_capacity = 100
  hash_key       = "enq_id"
  range_key      = "object_url"

  attribute {
    name = "enq_id"
    type = "S"
  }

  attribute {
    name = "object_url"
    type = "S"
  }

  attribute {
    name = "first_name"
    type = "S"
  }
  
  local_secondary_index {
    name            = "by_first_name"
    range_key       = "first_name"
    projection_type = "ALL"
  }

   attribute {
    name = "summary"
    type = "S"
  }

  global_secondary_index {
    name               = "by_summary"
    hash_key           = "summary"
    range_key          = "first_name"
    write_capacity     = 5
    read_capacity      = 10
    projection_type    = "INCLUDE"
    non_key_attributes = ["enq_image_file", "location"]
  }
  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }
  server_side_encryption {
    enabled = true
  }

  lifecycle {
    ignore_changes = [
      write_capacity, read_capacity
    ]
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "ec2-dynamodb-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "dynamodb_policy" {
  name   = "ec2-dynamodb-policy"
  role   = aws_iam_role.ec2_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [ 
          "dynamodb:BatchGet*",
          "dynamodb:DescribeStream",
          "dynamodb:DescribeTable",
          "dynamodb:Get*",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWrite*",
          "dynamodb:CreateTable",
          "dynamodb:Delete*",
          "dynamodb:Update*",
          "dynamodb:PutItem"
        ],
        "Effect": "Allow",
        "Resource": [
          "arn:aws:dynamodb:eu-west-2:account-id:table/enquiry_image_table"
        ]
    }
  ]
}
EOF
}