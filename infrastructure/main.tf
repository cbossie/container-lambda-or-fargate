terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = var.awsregion
  profile = var.awsprofile
  default_tags {
    tags = {
      "System" = "ContainerOrFargate"
    }
  }
}