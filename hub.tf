data "aws_availability_zones" "az" {
  state = "available"
}

data "aws_caller_identity" "hub" {
}

# -------
# Hub VPC
# -------
resource "aws_vpc" "hub" {
  cidr_block           = var.hub_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-hub-vpc"
  }
}

# Create VPC peering connection to spoke VPC
resource "aws_vpc_peering_connection" "hub" {
  peer_owner_id = data.aws_caller_identity.spoke.account_id
  peer_vpc_id   = aws_vpc.spoke.id
  vpc_id        = aws_vpc.hub.id
}

# Private subnets
resource "aws_subnet" "hub_private_a" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = cidrsubnet(var.hub_vpc_cidr, 8, 1)
  availability_zone = element(data.aws_availability_zones.az.names, 0)

  tags = {
    Name = "${var.name}-hub-private-subnet-a"
  }
}

resource "aws_subnet" "hub_private_b" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = cidrsubnet(var.hub_vpc_cidr, 8, 2)
  availability_zone = element(data.aws_availability_zones.az.names, 1)

  tags = {
    Name = "${var.name}-hub-private-subnet-b"
  }
}

# Route table and associations
resource "aws_route_table" "hub_private" {
  vpc_id = aws_vpc.hub.id

  tags = {
    Name = "${var.name}-hub-private-rt"
  }
}

resource "aws_route_table_association" "hub_private_a" {
  subnet_id      = aws_subnet.hub_private_a.id
  route_table_id = aws_route_table.hub_private.id
}

resource "aws_route_table_association" "hub_private_b" {
  subnet_id      = aws_subnet.hub_private_b.id
  route_table_id = aws_route_table.hub_private.id
}

# Add spoke VPC CIDR routing
resource "aws_route" "spoke_vpc" {
  route_table_id            = aws_route_table.hub_private.id
  destination_cidr_block    = var.spoke_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.hub.id
}

# Security group for VPC endpoints
resource "aws_security_group" "vpce" {
  description = "Security group for demo VPC endpoints"
  name        = "${var.name}-vpce"
  vpc_id      = aws_vpc.hub.id
  egress      = []
  ingress     = [{
    cidr_blocks      = [var.hub_vpc_cidr, var.spoke_vpc_cidr]
    description      = "Allow incoming HTTPS traffic from VPC CIDR"
    from_port        = 443
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 443
  }]

}

# AWS SSM VPC interface endpoints (ssm, ssmmessages, ec2messages)
resource "aws_vpc_endpoint" "ssm" {
  ip_address_type      = "ipv4"
  private_dns_enabled  = false
  security_group_ids   = [aws_security_group.vpce.id]
  service_name         = "com.amazonaws.ap-southeast-2.ssm"
  subnet_ids           = [aws_subnet.hub_private_a.id]
  vpc_endpoint_type    = "Interface"
  vpc_id               = aws_vpc.hub.id
  dns_options {
    dns_record_ip_type = "ipv4"
  }
  tags = {
    Name = "ssm-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  ip_address_type      = "ipv4"
  private_dns_enabled  = false
  security_group_ids   = [aws_security_group.vpce.id]
  service_name         = "com.amazonaws.ap-southeast-2.ec2messages"
  subnet_ids           = [aws_subnet.hub_private_a.id]
  vpc_endpoint_type    = "Interface"
  vpc_id               = aws_vpc.hub.id
  dns_options {
    dns_record_ip_type = "ipv4"
  }
  tags = {
    Name = "ssm-ec2messages-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  ip_address_type      = "ipv4"
  private_dns_enabled  = false
  security_group_ids   = [aws_security_group.vpce.id]
  service_name         = "com.amazonaws.ap-southeast-2.ssmmessages"
  subnet_ids           = [aws_subnet.hub_private_a.id]
  vpc_endpoint_type    = "Interface"
  vpc_id               = aws_vpc.hub.id
  dns_options {
    dns_record_ip_type = "ipv4"
  }
  tags = {
    Name = "ssmmessages-vpc-endpoint"
  }
}

# ------------
# Route 53 PHZ
# ------------
# Create a local variable to map SSM VPC endpoints attributes
locals {
  endpoints = {
    ssm = {
      zone_name = join(".", (reverse(split(".", aws_vpc_endpoint.ssm.service_name))))
      dns_name = aws_vpc_endpoint.ssm.dns_entry[0]["dns_name"]
      hosted_zone_id = aws_vpc_endpoint.ssm.dns_entry[0]["hosted_zone_id"]
    }
    ssmmessages = {
      zone_name = join(".", (reverse(split(".", aws_vpc_endpoint.ssmmessages.service_name))))
      dns_name = aws_vpc_endpoint.ssmmessages.dns_entry[0]["dns_name"]
      hosted_zone_id = aws_vpc_endpoint.ssmmessages.dns_entry[0]["hosted_zone_id"]
    }
    ec2messages = {
      zone_name = join(".", (reverse(split(".", aws_vpc_endpoint.ec2messages.service_name))))
      dns_name = aws_vpc_endpoint.ec2messages.dns_entry[0]["dns_name"]
      hosted_zone_id = aws_vpc_endpoint.ec2messages.dns_entry[0]["hosted_zone_id"]
    }
  }
}

# Create a private hosted zone
resource "aws_route53_zone" "zone" {
  for_each = local.endpoints

  name     = each.value["zone_name"]

  vpc {
    vpc_id = aws_vpc.hub.id
  }

  lifecycle {
    ignore_changes = [vpc]
  }
}

# Create an Alias record
resource "aws_route53_record" "root" {
  for_each = local.endpoints

  zone_id  = aws_route53_zone.zone[each.key].zone_id
  name     = aws_route53_zone.zone[each.key].name
  type     = "A"

  alias {
    name                   = each.value["dns_name"]
    zone_id                = each.value["hosted_zone_id"]
    evaluate_target_health = false
  }
}

# Authorise spoke VPC to be associated with the PHZs
resource "aws_route53_vpc_association_authorization" "zone" {
  for_each = local.endpoints

  vpc_id   = aws_vpc.spoke.id
  zone_id  = aws_route53_zone.zone[each.key].id
}

# Associate the PHZs to the spoke VPC
resource "aws_route53_zone_association" "zone" {
  provider = aws.spoke
  for_each = local.endpoints

  vpc_id   = aws_route53_vpc_association_authorization.zone[each.key].vpc_id
  zone_id  = aws_route53_vpc_association_authorization.zone[each.key].zone_id
}

# -------
# Outputs
# -------
output "route53_zone_ids" {
  value = {
    for k, v in local.endpoints : k => aws_route53_zone.zone[k].id
  }
}