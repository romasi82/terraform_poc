terraform {
  required_version = "~> 0.14.4"

  required_providers {
    aws = {
      version = "~> 3.24.0"
      source = "hashicorp/aws"
    }
  }
}

variable "environment" {
  type = string
}

variable "application" {
  type = string
}

variable "network" {
  type = object({
    cidr_block = string
    availability_zones = list(string)
    public_subnets = list(string)
    private_subnets = list(string)
  })
}

variable "services" {
  type = map(object({
    ami_id = string
    instance_type = string
    availability_zones = list(string)
  }))
}

provider "aws" {
  region = "us-west-2"
  profile = "marin"
}

module "network" {
  source = "./network"

  cidr_block = var.network.cidr_block
  availability_zones = var.network.availability_zones
  public_subnets = var.network.public_subnets
  private_subnets = var.network.private_subnets

  tags = {
    Environment = var.environment
    Application = var.application
  }
}

module "vpn" {
  source = "./services/vpn"

  ami_id = var.services.vpn.ami_id
  instance_type = var.services.vpn.instance_type
  availability_zones = var.services.vpn.availability_zones
  network = module.network

  tags = {
    Environment = var.environment
    Application = var.application
    Service = "vpn"
  }
}

module "bastion" {
  source = "./services/bastion"

  ami_id = var.services.bastion.ami_id
  instance_type = var.services.bastion.instance_type
  availability_zones = var.services.bastion.availability_zones
  network = module.network

  tags = {
    Environment = var.environment
    Application = var.application
    Service = "bastion"
  }
}

module "consul" {
  source = "./services/consul"

  ami_id = var.services.consul.ami_id
  instance_type = var.services.consul.instance_type
  availability_zones = var.services.consul.availability_zones
  network = module.network
  
  tags = {
    Environment = var.environment
    Application = var.application
    Service = "consul"
  }
}

module "nomad" {
  source = "./services/nomad"

  ami_id = var.services.nomad.ami_id
  instance_type = var.services.nomad.instance_type
  availability_zones = var.services.nomad.availability_zones
  network = module.network
  
  tags = {
    Environment = var.environment
    Application = var.application
    Service = "nomad"
  }
}

module "nomad-client" {
  source = "./services/nomad-client"

  ami_id = var.services.nomad-client.ami_id
  instance_type = var.services.nomad.instance_type
  availability_zones = var.services.nomad-client.availability_zones
  network = module.network
  
  tags = {
    Environment = var.environment
    Application = var.application
    Service = "nomad-client"
  }
}

output "network" {
  value = module.network
}

output "vpn" {
  value = {
    for instance in module.vpn.instances: instance.tags["Name"] => instance.public_ip
  }
}

output "bastion" {
  value = {
    for instance in module.bastion.instances: instance.tags["Name"] => instance.private_ip
  }
}

output "consul" {
  value = {
    for instance in module.consul.instances: instance.tags["Name"] => instance.private_ip
  }
}

output "nomad" {
  value = {
    for instance in module.nomad.instances: instance.tags["Name"] => instance.private_ip
  }
}

output "nomad-client" {
  value = {
    for instance in module.nomad-client.instances: instance.tags["Name"] => instance.private_ip
  }
}
