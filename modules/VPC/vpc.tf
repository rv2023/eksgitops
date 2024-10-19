data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "eks_cluster_vpc" {
  enable_dns_hostnames = var.dns_hosts
  enable_dns_support   = var.dns_support
  cidr_block           = var.vpc_cidr
  tags = {
    Name = "${var.env}-${var.vpc_name}"
  }
}

locals {
  # Flatten the list of public subnets into a map
  public_subnets = [
    for cluster_key in keys(var.eks_vpc) :
    [
      for idx in range(length(var.eks_vpc[cluster_key].public_subnets)) :
      merge(
        var.eks_vpc[cluster_key].public_subnets[idx],
        {
          #name = "${cluster_key}-${idx}"
          name = var.eks_vpc[cluster_key].public_subnets[idx].name
          cidr = var.eks_vpc[cluster_key].public_subnets[idx].cidr
          tags = var.eks_vpc[cluster_key].public_subnets[idx].tags
        }
      )
    ]
  ]
  flattened_public_subnets = flatten(local.public_subnets)

  # Flatten the list of private subnets into a map
  private_subnets = [
    for cluster_key in keys(var.eks_vpc) :
    [
      for idx in range(length(var.eks_vpc[cluster_key].private_subnets)) :
      merge(
        var.eks_vpc[cluster_key].private_subnets[idx],
        {
          name = var.eks_vpc[cluster_key].private_subnets[idx].name
          cidr = var.eks_vpc[cluster_key].private_subnets[idx].cidr
          tags = var.eks_vpc[cluster_key].private_subnets[idx].tags
        }
      )
    ]
  ]
  flattened_private_subnets = flatten(local.private_subnets)

  # List of Availability Zones
  azs = data.aws_availability_zones.available.names
}

resource "aws_subnet" "public_subnets" {
  for_each = { for idx, subnet in local.flattened_public_subnets : "${idx}" => subnet }

  vpc_id                  = aws_vpc.eks_cluster_vpc.id
  cidr_block              = each.value.cidr
  #availability_zone       = local.azs[each.key % length(local.azs)]
  availability_zone = var.azs[each.key % length(var.azs)]
  map_public_ip_on_launch = true
  tags = merge(
    {
      Name = each.value.name
    },
    {
      "kubernetes.io/role/elb" = "1"
    },
    each.value.tags
  )
}

resource "aws_subnet" "private_subnets" {
  for_each = { for idx, subnet in local.flattened_private_subnets : "${idx}" => subnet }

  vpc_id            = aws_vpc.eks_cluster_vpc.id
  cidr_block        = each.value.cidr
  #availability_zone = local.azs[each.key % length(local.azs)]
  availability_zone = var.azs[each.key % length(var.azs)]
  tags = merge(
    {
      Name = each.value.name
    },
    {
      "kubernetes.io/role/internal-elb" = "1"
    },
    each.value.tags
  )
}


resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.eks_cluster_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.eks_cluster_vpc.id

  tags = {
  Name = "Private Route Table"
  }
}

resource "aws_route_table_association" "private_route_table_association" {
  for_each = aws_subnet.private_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "public_route_table_association" {
  for_each = aws_subnet.public_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_cluster_vpc.id

  tags = {
  Name = "Internet Gateway"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id
  depends_on = [aws_internet_gateway.igw]

tags = {
  Name = "NAT Gateway"
  }
}

resource "aws_eip" "nat_eip" {
vpc = true
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

output "vpc_id"  {
  value = aws_vpc.eks_cluster_vpc.id
}