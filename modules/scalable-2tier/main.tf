/*
        SCALABLE 2-TIER (Client + Database)
*/
#--------------------------------------------------------------------------------------------------------------------
# Sc. Network
#--------------------------------------------------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.project_name}-VPC"
  }
}
resource "aws_eip" "this" {
  vpc = true
  tags = {
    Name = "${var.project_name}-EIP"
  }
}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.project_name}-IGW"
  }
}
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.public.0.id
  tags = {
    Name = "${var.project_name}-NGW"
  }
}
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index * 2)
  vpc_id                  = aws_vpc.this.id
  map_public_ip_on_launch = "true"
  availability_zone       = element(var.availability_zones, count.index)
  tags = {
    Name = "${var.project_name}-${trimprefix(element(var.availability_zones, count.index), var.region)}-PUB-SN"
  }
}
resource "aws_subnet" "private" {
  count                   = length(var.availability_zones)
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, (count.index * 2) + 1)
  vpc_id                  = aws_vpc.this.id
  map_public_ip_on_launch = "true"
  availability_zone       = element(var.availability_zones, count.index)
  tags = {
    Name = "${var.project_name}-${trimprefix(element(var.availability_zones, count.index), var.region)}-PRIV-SN"
  }
}
resource "aws_default_route_table" "this" {
  default_route_table_id = aws_vpc.this.default_route_table_id
  propagating_vgws       = []
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    Name = "${var.project_name}-IGW-RT"
  }
}
resource "aws_route_table" "nat_allocated" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = {
    Name = "${var.project_name}-NGW-RT"
  }
}
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public.*)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_default_route_table.this.id
}
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private.*)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.nat_allocated.id
}
