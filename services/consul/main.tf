
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
      for key, subnet in var.network.private_subnets: {
        availability_zone = subnet.availability_zone
        subnet_id = subnet.id
      }
    ] : availability_zone.availability_zone => availability_zone
  }
}

// IAM resources

resource "aws_iam_role" "instance_role" {
  name = "consul"
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "consul"
  role = element(concat(aws_iam_role.instance_role.*.name, [""]), 0)
}

resource "aws_iam_role_policy" "auto_discover_cluster" {
  name   = "auto-discover-cluster"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.auto_discover_cluster.json
}

data "aws_iam_policy_document" "auto_discover_cluster" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "autoscaling:DescribeAutoScalingGroups",
    ]

    resources = ["*"] // ["arn:aws:ec2:*"]
  }
}

// Security Groups

resource "aws_security_group" "consul" {
  name        = "consul"
  description = "Allow SSH inbound traffic"
  vpc_id      = var.network.vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

  ingress {
    description = "Consul DNS"
    from_port = 8600
    to_port = 8600
    protocol = "tcp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

  ingress {
    description = "Consul DNS"
    from_port = 8600
    to_port = 8600
    protocol = "udp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

  ingress {
    description = "Consul HTTP"
    from_port = 8500
    to_port = 8500
    protocol = "tcp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

  // ingress {
  //   description = "Consul gRPC"
  //   from_port = 8502
  //   to_port = 8502
  //   protocol = "tcp"
  //   cidr_blocks = [var.network.vpc.cidr_block]
  // }

  ingress {
    description = "Consul LAN Serf"
    from_port = 8301
    to_port = 8301
    protocol = "tcp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

  ingress {
    description = "Consul LAN Serf"
    from_port = 8301
    to_port = 8301
    protocol = "udp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

  ingress {
    description = "Consul WAN Serf"
    from_port = 8302
    to_port = 8302
    protocol = "tcp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

  ingress {
    description = "Consul WAN Serf"
    from_port = 8302
    to_port = 8302
    protocol = "udp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

  ingress {
    description = "Consul Server RPC"
    from_port = 8300
    to_port = 8300
    protocol = "tcp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

  // ingress {
  //   description = "Consul-Nomad Connect"
  //   from_port = 20000
  //   to_port = 32000
  //   protocol = "tcp"
  //   cidr_blocks = [var.network.vpc.cidr_block]
  // }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${var.tags.Application}-consul-sg"
    },
    var.tags
  )
}

// EC2 Instances

// resource "aws_instance" "consul" {
//   for_each = local.availability_zones

//   ami = var.ami_id
//   instance_type = var.instance_type
//   iam_instance_profile = aws_iam_instance_profile.instance_profile.name

//   availability_zone = each.value.availability_zone
//   subnet_id = each.value.subnet_id
//   vpc_security_group_ids = [aws_security_group.consul.id]
//   key_name = "deployer"

//   tags = merge(
//     {
//       Name = "${var.tags.Application}-consul"
//       Zone = each.value.availability_zone
//     },
//     var.tags
//   )
// }

resource "aws_instance" "consul" {
  count = 1
  ami = var.ami_id
  instance_type = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  availability_zone = var.network.private_subnets[0].availability_zone
  subnet_id = var.network.private_subnets[0].id
  vpc_security_group_ids = [aws_security_group.consul.id]
  key_name = "deployer"

  user_data = <<-EOF
    #!/bin/bash
    sudo hostname consul-${count.index}
    sudo /opt/consul/bin/run_consul.sh
  EOF

  tags = merge(
    {
      Name = "${var.tags.Application}-consul-${count.index}"
      Zone = var.network.private_subnets[0].availability_zone
    },
    var.tags
  )
}

output "instances" {
  value = aws_instance.consul
}