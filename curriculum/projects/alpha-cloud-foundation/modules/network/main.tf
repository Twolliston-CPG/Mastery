# Network module: a VPC with public, application, and data tiers across N AZs.
#
# Design decisions (see docs/adr/0002-subnet-sizing.md):
#  - Public subnets are deliberately SMALL (/24). They hold only NAT gateways
#    and load balancer ENIs. Sizing them like app subnets wastes thousands of IPs.
#  - App subnets are deliberately LARGE (/20). If this ever runs EKS, the VPC CNI
#    assigns one subnet IP PER POD, and re-CIDRing a live VPC is brutal.
#  - The data tier has NO default route at all. A database should never initiate
#    an outbound internet connection; denying it by ROUTING rather than by firewall
#    rule means even a misconfigured security group cannot create an exfil path.

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /24 public and data subnets, /20 app subnets, allocated so app subnets sit on
  # clean 16-block boundaries and the upper 3/4 of the VPC stays free.
  public_subnets = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, i) }
  data_subnets   = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, i + 3) }
  app_subnets    = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 4, i + 1) }

  name = "${var.project}-${var.environment}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = local.name }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = local.name }
}

# --------------------------------------------------------------- subnets ----
# for_each over a map keyed by AZ name gives STABLE addresses. With count,
# removing one AZ would shift indexes and destroy/recreate unrelated subnets.
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${local.name}-public-${each.key}"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1" # harmless now; required if EKS lands here later
  }
}

resource "aws_subnet" "app" {
  for_each = local.app_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name                              = "${local.name}-app-${each.key}"
    Tier                              = "app"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "data" {
  for_each = local.data_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${local.name}-data-${each.key}"
    Tier = "data"
  }
}

# ------------------------------------------------------------------- NAT ----
# One NAT gateway per AZ in prod (no cross-AZ data charges, no single point of
# failure). A single shared NAT in dev, because a NAT gateway is ~$32/month and
# dev does not need AZ-level resilience.
resource "aws_eip" "nat" {
  for_each = var.enable_nat ? (var.single_nat_gateway ? { (local.azs[0]) = local.azs[0] } : local.public_subnets) : {}
  domain   = "vpc"
  tags     = { Name = "${local.name}-nat-${each.key}" }
}

resource "aws_nat_gateway" "this" {
  for_each = aws_eip.nat

  allocation_id = each.value.id
  # NAT gateways MUST live in a public subnet -- they are routers and need their
  # own path to the internet. This is the single most common VPC mistake.
  subnet_id = aws_subnet.public[each.key].id

  tags       = { Name = "${local.name}-${each.key}" }
  depends_on = [aws_internet_gateway.this]
}

# -------------------------------------------------------- route tables ------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# One route table per AZ so each app subnet can use its own AZ's NAT gateway.
resource "aws_route_table" "app" {
  for_each = local.app_subnets
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${local.name}-app-${each.key}" }
}

resource "aws_route" "app_nat" {
  for_each = var.enable_nat ? local.app_subnets : {}

  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = var.single_nat_gateway ? (
    aws_nat_gateway.this[local.azs[0]].id
  ) : aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "app" {
  for_each       = aws_subnet.app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

# Data tier: its own route table with NO 0.0.0.0/0 route. Deliberate.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-data" }
}

resource "aws_route_table_association" "data" {
  for_each       = aws_subnet.data
  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}

# ------------------------------------------------------------- endpoints ----
# Gateway endpoints are FREE and remove S3/DynamoDB traffic from the NAT gateway
# entirely -- both a cost win and a security win (traffic never leaves AWS).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    [for rt in aws_route_table.app : rt.id],
    [aws_route_table.data.id],
  )
  tags = { Name = "${local.name}-s3" }
}

# ------------------------------------------------------------ flow logs -----
resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id               = aws_vpc.this.id
  traffic_type         = "REJECT" # REJECT only keeps volume (and cost) sane
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn         = aws_iam_role.flow_logs[0].arn
  tags                 = { Name = local.name }
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/vpc/${local.name}/flowlogs"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${local.name}-flow-logs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "flow-logs"
  role  = aws_iam_role.flow_logs[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
    }]
  })
}
