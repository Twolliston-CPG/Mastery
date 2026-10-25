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

# Contract: a CIDR, an AZ count and three switches in; VPC and subnet IDs out. The module owns
# routing and nothing above it: no security groups, no instances, no endpoints other than the
# free S3 gateway. Everything that runs in these subnets is another module's job.

# The subnet plan, computed once from the VPC CIDR. With a /16 such as 10.10.0.0/16:
#   cidrsubnet(vpc, 8, i)     adds 8 bits -> a /24;  i = 0,1,2   -> 10.10.0.0/24, .1.0/24, .2.0/24
#   cidrsubnet(vpc, 8, i + 3) the next three /24s;   i+3 = 3,4,5 -> 10.10.3.0/24, .4.0/24, .5.0/24
#   cidrsubnet(vpc, 4, i + 1) adds 4 bits -> a /20;  i+1 = 1,2,3 -> 10.10.16.0/20, .32.0/20, .48.0/20
# /20 number 0 would be 10.10.0.0-10.10.15.255, which is exactly where the six /24s live, so the
# app subnets start at number 1 and nothing overlaps. /20s 4 to 15 (10.10.64.0 upward) stay free.
# The maps are keyed by AZ NAME, and every for_each below inherits those keys: see the subnets
# comment for why that matters.
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /24 public and data subnets, /20 app subnets, allocated so app subnets sit on
  # clean 16-block boundaries and the upper 3/4 of the VPC stays free.
  public_subnets = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, i) }
  data_subnets   = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, i + 3) }
  app_subnets    = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 4, i + 1) }

  name = "${var.project}-${var.environment}"
}

# Which AZs exist in this region, read at plan time. slice() in locals keeps the first az_count
# of them, so the module works in any region without a per-region zone map. The cost of that
# generality is in the skip below: the set is stable only because AWS appends new zones.
data "aws_availability_zones" "available" {
  # checkov:skip=CKV_AWS_394: The check wants an allowlist filter on zone-name or zone-id so a new AZ can never enter the set. This module is region-agnostic by design (var.region, var.az_count), so pinning zone names would need a per-region map. The slice() in locals caps the set at az_count, and AWS appends new zones after the existing ones, so the first N stay stable. Pin zone-name in a real deployment.
  state = "available"
}

# The VPC itself. Both DNS flags on: hostnames is what lets an RDS endpoint and a VPC endpoint's
# private DNS resolve from inside, and both must be true before an interface endpoint can enable
# private DNS at all. Changing the CIDR later forces a replacement of everything in the VPC.
# (hostnames: instances and endpoints get resolvable names; support: the resolver at .2 answers.)
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = local.name }
}

# Every VPC gets a default security group that allows its members to talk to each other.
# Nothing here uses it; adopting it with no rules strips those and makes "forgot to set a
# security group" fail closed instead of open.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-default-DO-NOT-USE" }
}

# The only way packets enter or leave the VPC without NAT. One per VPC; the public route table
# points 0.0.0.0/0 at it. Nothing in an app or data subnet can use it directly, because their
# route tables never reference it; that, not the subnet name, is what "private" means.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = local.name }
}

# --------------------------------------------------------------- subnets ----
# for_each over a map keyed by AZ name gives STABLE addresses. With count,
# removing one AZ would shift indexes and destroy/recreate unrelated subnets.
# That is BF-34 from week 11: aws_subnet.public["us-east-1a"] survives the removal of
# us-east-1b; aws_subnet.public[1] does not survive the removal of [0].
#
# "Public" is a property of the ROUTE TABLE associated below (0.0.0.0/0 via the internet
# gateway), not of this block. A subnet with map_public_ip_on_launch = true and no IGW route
# has instances with public addresses that nothing can reach, which is a common misreading.
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key
  # Nothing is *launched* here. NAT gateways use an EIP and the ALB's ENIs get addresses from
  # the ELB service, so auto-assigning public IPs would only matter to a stray instance.
  map_public_ip_on_launch = false

  tags = {
    Name                     = "${local.name}-public-${each.key}"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1" # harmless now; required if EKS lands here later
  }
}

# Where the instances run. A /20 per AZ (4,094 usable addresses) because an EKS pod takes a
# subnet IP each, and growing a subnet means recreating it. Default route: this AZ's NAT.
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

# Where the database lives. Small (/24) because a subnet group needs a handful of addresses,
# and associated below with a route table that has no 0.0.0.0/0 at all.
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
# One Elastic IP per NAT gateway. The for_each expression is the whole dev/prod difference in
# this module: NAT off -> empty map, nothing built; single_nat_gateway -> a one-entry map keyed
# by the first AZ; otherwise the public-subnet map, so one EIP and one gateway per AZ. The
# gateway and the routes below take their keys from this map, so the choice is made once.
# domain = "vpc" is the only valid value since EC2-Classic; the provider v5 `vpc = true` form is gone.
resource "aws_eip" "nat" {
  for_each = var.enable_nat ? (var.single_nat_gateway ? { (local.azs[0]) = local.azs[0] } : local.public_subnets) : {}
  domain   = "vpc"
  tags     = { Name = "${local.name}-nat-${each.key}" }
}

# The NAT gateways, one per EIP above. A NAT gateway is a managed router that rewrites source
# addresses to its EIP, so app instances can reach the internet while nothing can reach them.
# About $32/month each plus per-GB processing, which is why dev shares one and why the S3
# gateway endpoint below exists. depends_on is explicit because no argument references the IGW,
# so Terraform cannot infer the order; created first, a gateway has no path out and comes up broken.
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
# One public route table for all AZs: every public subnet uses the same IGW, so there is no
# per-AZ decision to make. The local route for the VPC CIDR is implicit and cannot be removed.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-public" }
}

# The route that makes those subnets public. Remove it and the subnets are private in every
# way that matters, whatever their name or IP flag says.
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# A subnet uses the VPC's MAIN route table until an association says otherwise. Every subnet
# here is associated explicitly, so the main table (which has only the local route) never
# silently decides a subnet's routing.
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# One route table per AZ so each app subnet can use its own AZ's NAT gateway.
# Shared tables would force every AZ through one gateway: cross-AZ data charges on every byte,
# and one AZ's outage taking the others' egress with it.
resource "aws_route_table" "app" {
  for_each = local.app_subnets
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${local.name}-app-${each.key}" }
}

# The default route for each app subnet. With a single NAT every AZ points at the first AZ's
# gateway (cheap, not HA); otherwise each points at its own. With NAT off there is no default
# route, and instances can reach only the VPC and the S3 endpoint.
resource "aws_route" "app_nat" {
  for_each = var.enable_nat ? local.app_subnets : {}

  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = var.single_nat_gateway ? (
    aws_nat_gateway.this[local.azs[0]].id
  ) : aws_nat_gateway.this[each.key].id
}

# Each app subnet to its own AZ's table; the keys line up because both came from local.azs.
resource "aws_route_table_association" "app" {
  for_each       = aws_subnet.app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

# Data tier: its own route table with NO 0.0.0.0/0 route. Deliberate.
# The database can answer the app (replies follow the connection, not a route) and reach S3
# through the gateway endpoint for backups; it cannot start a connection to the internet even
# if someone opens its security group, because there is no route to send the packet on.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-data" }
}

# All data subnets share the one table: there is no per-AZ gateway to point at.
resource "aws_route_table_association" "data" {
  for_each       = aws_subnet.data
  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}

# ------------------------------------------------------------- endpoints ----
# Gateway endpoints are FREE and remove S3/DynamoDB traffic from the NAT gateway
# entirely -- both a cost win and a security win (traffic never leaves AWS).
# A gateway endpoint is a route, not an ENI: it adds a prefix-list route for S3's addresses to
# the tables listed, so S3 traffic from app and data subnets goes straight to the service.
# This is also how the data tier reaches S3 with no default route, and how week 6 Lab 3 proved
# "delete the NAT and S3 still works".
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
# Flow logs record accepted or rejected connections per ENI, not packets. REJECT only is the
# diagnostic that matters ("never arrived" vs "refused") at a fraction of the volume. count,
# not for_each: there is at most one, and the [0] index below is the price of that.
resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id               = aws_vpc.this.id
  traffic_type         = "REJECT" # REJECT only keeps volume (and cost) sane
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn         = aws_iam_role.flow_logs[0].arn
  tags                 = { Name = local.name }
}

# Where the flow logs land. Retention is the only cost control: without it the group keeps
# everything forever. The two skips are decisions, not oversights; read them.
resource "aws_cloudwatch_log_group" "flow_logs" {
  # checkov:skip=CKV_AWS_158: Encrypted at rest with the CloudWatch Logs service key. A customer-managed KMS key costs money monthly and protects nothing extra for REJECT-only flow logs.
  # checkov:skip=CKV_AWS_338: 14 (dev) / 30 (prod) days is enough to investigate an incident. A year of retention is a compliance requirement this project does not have.
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/vpc/${local.name}/flowlogs"
  retention_in_days = var.log_retention_days
}

# The identity the flow-logs service assumes to write. The trust policy names the service
# principal and nothing else, so no user or instance can assume this role.
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

# What that role may do: write streams and events into this one log group (the :* covers its
# streams), plus the two Describe calls the service makes before writing. Not logs:* on *.
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
