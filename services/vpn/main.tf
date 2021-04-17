
variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "network" {}

variable "tags" {
  type = map(string)
}

locals {
  availability_zones = {
    for availability_zone in [
      for key, subnet in var.network.public_subnets: {
        availability_zone = subnet.availability_zone
        subnet_id = subnet.id
      }
    ] : availability_zone.availability_zone => availability_zone
  }
}

resource "aws_security_group" "vpn" {
  name        = "vpn"
  description = "Allow OpenVPN inbound traffic"
  vpc_id      = var.network.vpc.id

  ingress {
    description = "Custom UDP"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Custom TCP"
    from_port   = 945
    to_port     = 945
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Custom TCP"
    from_port   = 943
    to_port     = 943
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${var.tags.Application}-vpn-sg"
    },
    var.tags
  )
}

resource "aws_instance" "vpn" {
  for_each = local.availability_zones

  ami           = var.ami_id
  instance_type = var.instance_type

  availability_zone           = each.value.availability_zone
  subnet_id                   = each.value.subnet_id
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.vpn.id]

  key_name = "deployer"

  tags = merge(
    {
      Name = "${var.tags.Application}-vpn"
      Zone = each.value.availability_zone
    },
    var.tags
  )
}

output "instances" {
  value = aws_instance.vpn
}