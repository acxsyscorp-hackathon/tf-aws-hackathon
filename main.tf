provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "region2"
  region = "us-west-1"
}

data "aws_caller_identity" "current" {}

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
  name                  = "hackathon-postgres"
  engine                = "postgres"
  engine_version        = "14"
  family                = "postgres14" # DB parameter group
  major_engine_version  = "14"         # DB option group
  instance_class        = "db.t4g.large"
  allocated_storage     = 20
  max_allocated_storage = 100
  port                  = 5432
}


#CREATE VPCS and SECURITY GROUPS#

module "vpc_region1" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
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

  name        = local.name
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

  name = local.name
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

  name        = local.name
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

module "kms" {
  source      = "terraform-aws-modules/kms/aws"
  version     = "~> 1.0"
  description = "KMS key for cross region replica DB"

  # Aliases
  aliases                 = [local.name]
  aliases_use_name_prefix = true

  key_owners = [data.aws_caller_identity.current.id]

  tags = local.tags

  providers = {
    aws = aws.region2
  }
}

# CREATE DB

module "master" {
  source = "./modules/terraform-azurerm-postgres"

  identifier = "${local.name}-master"

  engine               = local.engine
  engine_version       = local.engine_version
  #family               = local.family
  #major_engine_version = local.major_engine_version
  instance_class       = local.instance_class

  allocated_storage     = local.allocated_storage
  max_allocated_storage = local.max_allocated_storage

  db_name  = "replicaPostgresql"
  username = "replica_postgresql"
  port     = local.port

  multi_az               = true
  db_subnet_group_name   = module.vpc_region1.database_subnet_group_name
  vpc_security_group_ids = [module.security_group_region1.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Backups are required in order to create a replica
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = local.tags
}

module "replica" {
  source = "./modules/terraform-azurerm-postgres"
  
  providers = {
    aws = aws.region2
  }

  identifier = "${local.name}-replica"

  # Source database. For cross-region use db_instance_arn
  replicate_source_db = module.master.db_instance_arn

  engine               = local.engine
  engine_version       = local.engine_version
  #family               = local.family
  #major_engine_version = local.major_engine_version
  instance_class       = local.instance_class
  kms_key_id           = module.kms.key_arn

  allocated_storage     = local.allocated_storage
  max_allocated_storage = local.max_allocated_storage

  # Not supported with replicas
  manage_master_user_password = false

  # Username and password should not be set for replicas
  port = local.port

  # parameter group for replica is inherited from the source database
  #create_db_parameter_group = false

  multi_az               = false
  vpc_security_group_ids = [module.security_group_region2.security_group_id]

  maintenance_window              = "Tue:00:00-Tue:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  # Specify a subnet group created in the replica region
  db_subnet_group_name = module.vpc_region2.database_subnet_group_name

  tags = local.tags
}
