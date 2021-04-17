
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
  name = "nomad-client"
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
  name = "nomad-client"
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

resource "aws_security_group" "nomad-client" {
  name        = "nomad-client"
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
    description = "Countdash"
    from_port   = 9001
    to_port     = 9002
    protocol    = "tcp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

  ingress {
    description = "Nomad WAN Serf"
    from_port = 4648
    to_port = 4648
    protocol = "tcp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

  ingress {
    description = "Nomad Server RPC"
    from_port = 4647
    to_port = 4647
    protocol = "tcp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

  ingress {
    description = "Nomad Dynamic Ports"
    from_port = 20000
    to_port = 32000
    protocol = "tcp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

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
    description = "Nginx"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [var.network.vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${var.tags.Application}-nomad-client-sg"
    },
    var.tags
  )
}

// EC2 Instances

// resource "aws_instance" "nomad-client" {
//   for_each = local.availability_zones

//   ami = var.ami_id
//   instance_type = var.instance_type
//   iam_instance_profile = aws_iam_instance_profile.instance_profile.name

//   availability_zone = each.value.availability_zone
//   subnet_id = each.value.subnet_id
//   vpc_security_group_ids = [aws_security_group.nomad-client.id]
//   key_name = "deployer"

//   tags = merge(
//     {
//       Name = "${var.tags.Application}-nomad-client-${some_index}"
//       Zone = each.value.availability_zone
//     },
//     var.tags
//   )
// }

resource "aws_instance" "nomad-client" {
  count = 3
  ami = var.ami_id
  instance_type = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  availability_zone = var.network.private_subnets[0].availability_zone
  subnet_id = var.network.private_subnets[0].id
  vpc_security_group_ids = [aws_security_group.nomad-client.id]
  key_name = "deployer"

  user_data = <<-EOF
    #!/bin/bash
    sudo hostname nomad-client-${count.index}
    sudo /opt/consul/bin/run_consul.sh
    sudo /opt/nomad/bin/run_nomad.sh
  EOF

  tags = merge(
    {
      Name = "${var.tags.Application}-nomad-client-${count.index}"
      Zone = var.network.private_subnets[0].availability_zone
    },
    var.tags
  )
}

// Add Private Hosted Zone For the Demo
// Nginx is running on the nomad clients

resource "aws_route53_zone" "private" {
  name = "searchfunc13.com"

  vpc {
    vpc_id = var.network.vpc.id
  }
}

resource "aws_route53_record" "demo" {
  zone_id = aws_route53_zone.private.id
  name    = "demo.searchfunc13.com"
  type    = "A"
  ttl     = "300"
  records = [
    for instance in aws_instance.nomad-client: instance.private_ip
  ]
}

output "instances" {
  value = aws_instance.nomad-client
}