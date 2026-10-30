# dev: single AZ NAT, no Multi-AZ database, smaller instances.
# Same modules as prod -- only the INPUTS differ. That is the whole point.

# Four module calls. Their order in this file does not matter: Terraform builds the graph from
# the references (compute needs network's subnet ids, database needs compute's security group,
# observability needs all three) and applies in dependency order.

# The VPC and its three tiers across the AZs. The outputs this root consumes are subnet ids
# and the vpc id; route tables, NAT and flow logs stay inside the module.
module "network" {
  source = "../../modules/network"

  # CIDR and width: 10.10.0.0/16, distinct from prod's 10.20.0.0/16 so the two could be peered later without overlap.
  # az_count two AZs: enough to prove the multi-AZ design, half the NAT and subnet count of prod.
  project     = var.project
  environment = "dev"
  region      = var.region
  vpc_cidr    = "10.10.0.0/16"
  az_count    = 2

  # Egress and evidence: one NAT gateway for the whole VPC: about $32 a month instead of $64. A single point of failure, accepted in dev.
  # Flow logs on, with a retention that matches how long dev data is worth keeping.
  enable_nat         = true
  single_nat_gateway = true # ~$32/mo instead of ~$64. Not HA. Fine for dev.
  enable_flow_logs   = true
  log_retention_days = 7
}

# The load balancer, the auto scaling group and the instance role. It takes the network's subnets
# and the database's secret ARN, and returns the identifiers the observability module alarms on.
module "compute" {
  source = "../../modules/compute"

  project           = var.project
  environment       = "dev"
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  app_subnet_ids    = module.network.app_subnet_ids

  # Capacity: the smallest shape that runs the app: t3.micro, one instance, room for one more during a rollout.
  instance_type    = "t3.micro"
  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  # The application contract: the port the instances listen on, the path the target group probes,
  # the certificate (null serves plain HTTP in the lab), and the secret the instance role may read.
  app_port          = 8080
  health_check_path = "/health"
  certificate_arn   = var.certificate_arn
  db_secret_arn     = module.database.secret_arn

  tags = local.common_tags
}

# RDS in the data tier. It takes the data subnets and the app security group (by id, so its one
# ingress rule references the app tier) and returns the endpoint and the secret ARN.
module "database" {
  source = "../../modules/database"

  project     = var.project
  environment = "dev"
  vpc_id      = module.network.vpc_id

  data_subnet_ids       = module.network.data_subnet_ids
  app_security_group_id = module.compute.app_security_group_id

  # Availability and retention: no standby and one day of backups: dev data is disposable, and this is most of the cost difference from prod.
  instance_class        = "db.t4g.micro"
  multi_az              = false # dev does not need AZ failover
  backup_retention_days = 1
}

# Alarms, the topic and the dashboard, wired to the identifiers the other three modules exported.
# alert_email null means the alarms reach nobody; set it and confirm the subscription.
module "observability" {
  source = "../../modules/observability"

  project     = var.project
  environment = "dev"
  region      = var.region

  alb_arn_suffix          = module.compute.alb_arn_suffix
  target_group_arn_suffix = module.compute.target_group_arn_suffix
  asg_name                = module.compute.asg_name
  db_instance_id          = module.database.identifier
  alert_email             = var.alert_email
}
