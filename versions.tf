terraform {
  required_version = ">= 1.0"
  cloud {
    organization = "acxsyscorp-hackathon"

    workspaces {
      name = "tf-aws-hackathon"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.62"
    }
  }
}