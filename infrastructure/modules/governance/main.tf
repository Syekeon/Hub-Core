locals {
  tags = {
    project      = var.workload
    environment  = var.environment
    owner        = var.owner
    cost_center  = var.cost_center
  }
}
