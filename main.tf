provider "aws" {
  region = var.primary_region
}

locals {
    tags = {
        Name = "Hachathon"
    }

}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}


#CREATE VPC#

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name
  cidr = var.vpc_cidr

  azs              = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets   = [for k, v in azs : cidrsubnet(var.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in azs : cidrsubnet(var.vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in azs : cidrsubnet(var.vpc_cidr, 8, k + 6)]

  create_database_subnet_group = true

  tags = local.tags
}


