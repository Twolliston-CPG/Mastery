# dev: single AZ NAT, no Multi-AZ database, smaller instances.
# Same modules as prod -- only the INPUTS differ. That is the whole point.

module "network" {
  source = "../../modules/network"

  project     = var.project
  environment = "dev"
  region      = var.region
  vpc_cidr    = "10.10.0.0/16"
  az_count    = 2

  enable_nat         = true
  single_nat_gateway = true # ~$32/mo instead of ~$64. Not HA. Fine for dev.
  enable_flow_logs   = true
  log_retention_days = 7
}

module "compute" {
  source = "../../modules/compute"

  project           = var.project
  environment       = "dev"
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  app_subnet_ids    = module.network.app_subnet_ids

  instance_type    = "t3.micro"
  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  app_port          = 8080
  health_check_path = "/health"
  certificate_arn   = var.certificate_arn
  db_secret_arn     = module.database.secret_arn

  tags = local.common_tags
}

module "database" {
  source = "../../modules/database"

  project     = var.project
  environment = "dev"
  vpc_id      = module.network.vpc_id

  data_subnet_ids       = module.network.data_subnet_ids
  app_security_group_id = module.compute.app_security_group_id

  instance_class        = "db.t4g.micro"
  multi_az              = false # dev does not need AZ failover
  backup_retention_days = 1
}

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
