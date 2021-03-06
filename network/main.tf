
variable "cidr_block" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

locals {
  public_subnets = {
    for subnet in flatten([
      for index, zone in var.availability_zones : {
        index = index
        cidr_block = var.public_subnets[index]
        availability_zone = zone
      }
    ]) : subnet.cidr_block => subnet
  }

  private_subnets = {
    for subnet in flatten([
      for index, zone in var.availability_zones : {
        index = index
        cidr_block = var.private_subnets[index]
        availability_zone = zone
      }
    ]) : subnet.cidr_block => subnet
  }

  nat_mapping = {
    for mapping in flatten([
      for index, cidr_block in var.private_subnets : {
        cidr_block = cidr_block
        target_cidr_block = var.public_subnets[index]
      }
    ]) : mapping.cidr_block => mapping
  }
}

// create VPC

resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = merge(
    {
      Name = "${var.tags.Application}-vpc"
    },
    var.tags
  )
}

// create an IGW

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(
    {
      Name = "${var.tags.Application}-igw"
    },
    var.tags
  )
}

// create public subnets

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id = aws_vpc.vpc.id
  cidr_block = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = merge(
    {
      Name = "${var.tags.Application}-public-${each.value.index}"
      Zone = each.value.availability_zone
      Public = "yes"
    },
    var.tags
  )
}

// create private subnets

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.vpc.id
  cidr_block = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = merge(
    {
      Name = "${var.tags.Application}-private-${each.value.index}"
      Zone = each.value.availability_zone
    },
    var.tags
  )
}

// create NAT gateway (if desired)

resource "aws_eip" "nat" {
  for_each = local.public_subnets

  vpc = true

  tags = merge(
    {
      Name = "${var.tags.Application}-eip-${each.value.index}"
    },
    var.tags
  )
}

resource "aws_nat_gateway" "nat" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.nat[each.value.cidr_block].id
  subnet_id = each.value.id

  tags = merge(
    {
      Name = "${var.tags.Application}-nat-${local.public_subnets[each.value.cidr_block].index}"
      Zone = local.public_subnets[each.value.cidr_block].availability_zone
    },
    var.tags
  )
}

// create route tables

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(
    {
      Name = "${var.tags.Application}-public"
    },
    var.tags
  )
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.vpc.id

  tags = merge(
    {
      Name = "${var.tags.Application}-private"
      Zone = each.value.availability_zone
    },
    var.tags
  )
}

// create route table associations

// resource "aws_main_route_table_association" "main" {
//   for_each = aws_subnet.private

//   vpc_id = aws_vpc.vpc.id
//   route_table_id = aws_route_table.private[each.value.cidr_block].id
// }

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id = each.value.id
  route_table_id = aws_route_table.private[each.value.cidr_block].id
}

// create routes

resource "aws_route" "ingress" {
  route_table_id = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

resource "aws_route" "nat" {
  for_each = local.nat_mapping

  route_table_id = aws_route_table.private[each.value.cidr_block].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat[each.value.target_cidr_block].id
}

output "vpc" {
  value = aws_vpc.vpc
}

output "public_subnets" {
  value = [
    for subnet_key, subnet in aws_subnet.public: {
      id = subnet.id
      cidr_block = subnet.cidr_block
      availability_zone = subnet.availability_zone
    }
  ]
}

output "private_subnets" {
  value = [
    for subnet_key, subnet in aws_subnet.private: {
      id = subnet.id
      cidr_block = subnet.cidr_block
      availability_zone = subnet.availability_zone
    }
  ]
}

output "nat" {
  value = aws_nat_gateway.nat
}