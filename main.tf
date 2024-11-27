provider "aws" {
  region = var.primary_region
}

provider "aws" {
  alias  = "region2"
  region = var.seconday_region
}

locals {
    tags = {
        Name               = "Hachathon"
        project            = "Hackathon Test"
        environment        = "shared services"
        WorkloadName       = "Hackathon"
        DataClassification = "General"
        Criticality        = "SUPER HIGH"
        OpsCommitment      = "Platform operations"
        OpsTeam            = "Cloud Operations"
        ManagedBy          = "Terraform"
    }

    engine                = "postgres"
    engine_version        = "14"
    family                = "postgres14" # DB parameter group
    major_engine_version  = "14"         # DB option group
    instance_class        = "db.t4g.large"
    allocated_storage     = 20
    max_allocated_storage = 100
    port                  = 5432
}


data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}


#CREATE VPC#

module "vpc_region1" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name
  cidr = "10.100.0.0/18"

  azs              = ["${var.primary_region}a", "${var.primary_region}b", "${var.primary_region}c"]
  public_subnets   = ["10.100.0.0/24", "10.100.1.0/24", "10.100.2.0/24"]
  private_subnets  = ["10.100.3.0/24", "10.100.4.0/24", "10.100.5.0/24"]
  database_subnets = ["10.100.7.0/24", "10.100.8.0/24", "10.100.9.0/24"]

  create_database_subnet_group = true

  tags = local.tags
}

#CREATE SECURITY GROUPS#

module "security_group_region1" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = var.name
  description = "Replica PostgreSQL hackathon security group"
  vpc_id      = module.vpc_region1.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = module.vpc_region1.vpc_cidr_block
    },
  ]

  tags = local.tags
}


module "vpc_region2" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.region2
  }

  name = var.name
  cidr = "10.100.0.0/18"

  azs              = ["${var.seconday_region}a", "${var.seconday_region}b", "${var.seconday_region}c"]
  public_subnets   = ["10.100.0.0/24", "10.100.1.0/24", "10.100.2.0/24"]
  private_subnets  = ["10.100.3.0/24", "10.100.4.0/24", "10.100.5.0/24"]
  database_subnets = ["10.100.7.0/24", "10.100.8.0/24", "10.100.9.0/24"]

  create_database_subnet_group = true

  tags = local.tags
}

module "security_group_region2" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.region2
  }

  name        = var.name
  description = "Replica PostgreSQL example security group"
  vpc_id      = module.vpc_region2.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = module.vpc_region2.vpc_cidr_block
    },
  ]

  tags = local.tags
}