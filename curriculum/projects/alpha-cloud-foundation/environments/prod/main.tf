# dev: single AZ NAT, no Multi-AZ database, smaller instances.
# Same modules as prod -- only the INPUTS differ. That is the whole point.

module "network" {
  source = "../../modules/network"

  project     = var.project
  environment = "prod"
  region      = var.region
  vpc_cidr    = "10.20.0.0/16"
  az_count    = 3

  enable_nat         = true
  single_nat_gateway = false # one NAT per AZ: no cross-AZ charges, no SPOF
  enable_flow_logs   = true
  log_retention_days = 30
}

module "compute" {
  source = "../../modules/compute"

  project           = var.project
  environment       = "prod"
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  app_subnet_ids    = module.network.app_subnet_ids

  instance_type    = "t3.small"
  min_size         = 2
  max_size         = 6
  desired_capacity = 2

  app_port          = 8080
  health_check_path = "/health"
  certificate_arn   = var.certificate_arn
  db_secret_arn     = module.database.secret_arn

  tags = local.common_tags
}

module "database" {
  source = "../../modules/database"

  project     = var.project
  environment = "prod"
  vpc_id      = module.network.vpc_id

  data_subnet_ids       = module.network.data_subnet_ids
  app_security_group_id = module.compute.app_security_group_id

  instance_class        = "db.t4g.micro"
  multi_az              = true # availability: synchronous standby in another AZ
  backup_retention_days = 14
}

module "observability" {
  source = "../../modules/observability"

  project     = var.project
  environment = "prod"
  region      = var.region

  alb_arn_suffix          = module.compute.alb_arn_suffix
  target_group_arn_suffix = module.compute.target_group_arn_suffix
  asg_name                = module.compute.asg_name
  db_instance_id          = module.database.identifier
  alert_email             = var.alert_email
}
