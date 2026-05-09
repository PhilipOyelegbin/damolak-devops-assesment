# ==============================================================
# Terraform configuration for AWS infrastructure
# ==============================================================

module "network" {
  source       = "../../modules/network"
  project_name = var.project_name
  region       = var.region
  vpc_cidr     = var.vpc_cidr
  environment  = "production"
}

module "container" {
  source          = "../../modules/container"
  project_name    = var.project_name
  environment     = "production"
  repository_name = "${var.project_name}-production-backend"
  force_delete    = true
}

module "instance" {
  source        = "../../modules/instance"
  project_name  = var.project_name
  instance_type = var.instance_type
  subnet_id     = module.network.subnet_id
  backend_sg_id = module.network.backend_sg_id
  environment   = "production"
}

module "monitoring" {
  source             = "../../modules/monitoring"
  project_name       = var.project_name
  region             = var.region
  vpc_id             = module.network.vpc_id
  vpc_cidr_blocks    = [module.network.vpc_cidr]
  backend_sg_ids     = [module.network.backend_sg_id]
  alert_email        = var.alert_email
  instance_ids       = [module.instance.instance_id]
  enable_dashboard   = var.enable_dashboard
  dashboard_name     = var.dashboard_name
  log_retention_days = var.log_retention_days
}
