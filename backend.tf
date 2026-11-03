terraform {
  backend "s3" {
    # ============================================================
    # TODO: Isi dengan nama bucket S3 yang sudah kamu buat secara manual
    # Format: lks-mart-tfstate-<KotaAnda-NamaAnda>
    # Contoh: lks-mart-tfstate-surabaya-budi
    # ============================================================
    bucket = "lks-mart-tfstate-blitar-revo"
    key    = "lks-cloudmart/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.9.0"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "CloudMart"
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}
