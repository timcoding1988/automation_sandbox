variable "compartment_ocid" {
  description = "OCID of the compartment where resources will be created"
  type        = string
}

variable "region" {
  description = "OCI region for resource creation"
  type        = string
  default     = "us-ashburn-1"
}

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "oci-images"
}

variable "tfstate_bucket_name" {
  description = "Name of the Object Storage bucket for Terraform state"
  type        = string
  default     = "oci-images-tfstate"
}

variable "enable_tfstate_bucket" {
  description = "Whether to create the Terraform state bucket"
  type        = bool
  default     = true
}
