terraform {
  required_version = "<=1.6.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = "default"
}

resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.20.0.0/16"

  tags = {
    Name                               = "dev_vpc"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

resource "aws_internet_gateway" "dev_public_igw" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name                               = "dev_public_igw"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "dev_subnet_public_1" {
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = "10.20.4.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "dev_subnet_public_1"
  }
}

resource "aws_route_table" "dev_public_rt" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name                               = "dev_public_rt"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

resource "aws_route" "dev_route_1" {
  route_table_id         = aws_route_table.dev_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.dev_public_igw.id
}

resource "aws_route_table_association" "dev_public_route_1" {
  subnet_id      = aws_subnet.dev_subnet_public_1.id
  route_table_id = aws_route_table.dev_public_rt.id
}

data "aws_iam_instance_profile" "bucket-policy" {
  name = "bucket-policy"
}

resource "aws_security_group" "ssh_web_traffic_sg" {
  name        = "Security-Group"
  description = "Allow SSH (restricted), HTTP, and HTTPS traffic"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description = "Allow SSH from trusted IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
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

  tags = {
    Name = "SSH-HTTP-HTTPS Security Group"
  }
}

resource "aws_instance" "ansible_controller" {
  ami                  = var.instance_ami_type
  instance_type        = var.instance_type_controller
  key_name             = "testing-dev-1"
  subnet_id            = aws_subnet.dev_subnet_public_1.id
  iam_instance_profile = data.aws_iam_instance_profile.bucket-policy.name

  vpc_security_group_ids = [
    aws_security_group.ssh_web_traffic_sg.id
  ]

  user_data = file("user-script-controller.sh")

  tags = {
    "Name"        = "ansible_controller"
    "Environment" = "Development"
  }
}

resource "time_sleep" "wait_before_clients" {
  depends_on      = [aws_instance.ansible_controller]
  create_duration = "90s"
}

resource "aws_instance" "ansible_client" {
  count                = var.client_instance_count
  ami                  = var.instance_ami_type
  instance_type        = var.instance_type_client
  key_name             = "testing-dev-1"
  subnet_id            = aws_subnet.dev_subnet_public_1.id
  iam_instance_profile = data.aws_iam_instance_profile.bucket-policy.name

  vpc_security_group_ids = [
    aws_security_group.ssh_web_traffic_sg.id
  ]

  user_data = file("user-script-client.sh")

  tags = {
    "Name" = "ansible_client"
  }

  depends_on = [time_sleep.wait_before_clients]
}

variable "instance_ami_type" {
  description = "The Image ID to be used"
  type        = string
  # default = "ami-0045d7fc2ad003464" us-east-1
  #  default     = "ami-02b71655113f1e03a"
  # default     = "ami-02b71655113f1e03a" ap-south-2
  default = "ami-03bb6d83c60fc5f7c"
}

variable "region" {
  description = "The regions used"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type_controller" {
  description = "Instance type for the Ansible Controller server"
  type        = string
  default     = "t2.micro"
}

variable "instance_type_client" {
  description = "Instance type for the Ansible Client server"
  type        = string
  default     = "t2.medium"
}

variable "client_instance_count" {
  type        = number
  default     = 1
  description = "Number of Ansible Client instances to create"
}

output "controller_public_ip" {
  description = "The ansible_controller Instance Public IP"
  value       = aws_instance.ansible_controller.public_ip
}

output "client_public_ip" {
  description = "Public IPs of the Ansible client instances"
  value       = aws_instance.ansible_client[*].public_ip
}
