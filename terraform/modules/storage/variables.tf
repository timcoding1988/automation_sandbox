variable "compartment_ocid" {
  description = "OCID of the compartment"
  type        = string
}

variable "bucket_name" {
  description = "Name of the Object Storage bucket for Terraform state"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "create_bucket" {
  description = "Whether to create the Terraform state bucket"
  type        = bool
  default     = true
}

variable "create_artifacts_bucket" {
  description = "Whether to create the artifacts bucket"
  type        = bool
  default     = false
}

variable "create_import_bucket" {
  description = "Whether to create the image import bucket"
  type        = bool
  default     = false
}
