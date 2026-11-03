# ============================================================
# VARIABLES — CloudMart Infrastructure
# ============================================================

variable "aws_region" {
  description = "AWS Region untuk deployment"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Prefix nama resource"
  type        = string
  default     = "lks-mart"
}

variable "db_name" {
  description = "Nama database RDS MySQL"
  type        = string
  default     = "cloudmartdb"
}

variable "db_username" {
  description = "Username master untuk RDS MySQL"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Password master untuk RDS MySQL"
  type        = string
  sensitive   = true
  default     = "LKS-CloudMart26!"
}

variable "s3_assets_bucket_name" {
  description = "Nama bucket S3 untuk aset produk (format: lks-mart-assets-<kota-nama>)"
  type        = string
  default     = "lks-mart-assets-default"
}

variable "vpc_cidr" {
  description = "CIDR block untuk VPC"
  type        = string
  default     = "10.20.0.0/16"
}
