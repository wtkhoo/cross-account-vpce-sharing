data "aws_ssm_parameter" "aml_latest_ami" {
  provider = aws.spoke
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

data "aws_caller_identity" "spoke" {
  provider = aws.spoke
}

# ---------
# Spoke VPC
# ---------
resource "aws_vpc" "spoke" {
  provider             = aws.spoke
  cidr_block           = var.spoke_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-spoke-vpc"
  }
}

# Accept VPC peering connection from hub VPC
resource "aws_vpc_peering_connection_accepter" "spoke" {
  provider                  = aws.spoke
  vpc_peering_connection_id = aws_vpc_peering_connection.hub.id
  auto_accept               = true
}

# Private subnets
resource "aws_subnet" "spoke_private_a" {
  provider          = aws.spoke
  vpc_id            = aws_vpc.spoke.id
  cidr_block        = cidrsubnet(var.spoke_vpc_cidr, 8, 1)
  availability_zone = element(data.aws_availability_zones.az.names, 0)

  tags = {
    Name = "${var.name}-spoke-private-subnet-a"
  }
}

resource "aws_subnet" "spoke_private_b" {
  provider          = aws.spoke
  vpc_id            = aws_vpc.spoke.id
  cidr_block        = cidrsubnet(var.spoke_vpc_cidr, 8, 2)
  availability_zone = element(data.aws_availability_zones.az.names, 1)

  tags = {
    Name = "${var.name}-spoke-private-subnet-b"
  }
}

# Route table and associations
resource "aws_route_table" "spoke_private" {
  provider = aws.spoke
  vpc_id   = aws_vpc.spoke.id

  tags = {
    Name = "${var.name}-spoke-private-rt"
  }
}

resource "aws_route_table_association" "spoke_private_a" {
  provider       = aws.spoke
  subnet_id      = aws_subnet.spoke_private_a.id
  route_table_id = aws_route_table.spoke_private.id
}

resource "aws_route_table_association" "spoke_private_b" {
  provider       = aws.spoke
  subnet_id      = aws_subnet.spoke_private_b.id
  route_table_id = aws_route_table.spoke_private.id
}

# Add hub VPC CIDR routing
resource "aws_route" "hub_vpc" {
  provider                  = aws.spoke
  route_table_id            = aws_route_table.spoke_private.id
  destination_cidr_block    = var.hub_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.hub.id
}

# Security group for EC2
resource "aws_security_group" "ec2" {
  provider    = aws.spoke
  description = "Security group for demo EC2 workloads"
  name        = "${var.name}-ec2"
  vpc_id      = aws_vpc.spoke.id 
  egress      = [{
    cidr_blocks      = []
    description      = "HTTPS rule for VPC endpoints SG chaining"
    from_port        = 443
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = ["${data.aws_caller_identity.hub.account_id}/${aws_security_group.vpce.id}"]
    self             = false
    to_port          = 443
  }]
  ingress     = []
}

# --------------------
# IAM role and profile
# --------------------
resource "aws_iam_role" "ec2_ssm_role" {
  provider             = aws.spoke
  name                 = "${var.name}-role"
  assume_role_policy   = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_instance_profile" "ssm_demo" {
  provider = aws.spoke
  name     = "${var.name}-profile"
  role     = aws_iam_role.ec2_ssm_role.name
}

# ------------
# EC2 for demo
# ------------
# EC2 Linux
resource "aws_instance" "ssm_demo_linux" {
  provider               = aws.spoke
  ami                    = data.aws_ssm_parameter.aml_latest_ami.value
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.ssm_demo.name
  subnet_id              = aws_subnet.spoke_private_a.id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  tags = {
    Name = "${var.name}-linux"
  }
}

# -------
# Outputs
# -------
output "ec2_linux_instance_id" {
  description = "The instance ID of the Linux demo instance"
  value       = aws_instance.ssm_demo_linux.id
}
