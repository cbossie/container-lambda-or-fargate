variable "awsprofile" {
  type        = string
  description = "profile to use"
}

variable "awsregion" {
  type        = string
  description = "region to use"
}

variable "vpccidr" {
  type        = string
  description = "CIDR range"
  default     = "10.0.0.0/16"
}

variable "ecr_repository" {
  type        = string
  description = "Repository to Use"
}