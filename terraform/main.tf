# OCI Image Building Infrastructure
# Creates network and storage resources for Packer image builds

module "network" {
  source = "./modules/network"

  compartment_ocid = var.compartment_ocid
  vcn_cidr         = var.vcn_cidr
  subnet_cidr      = var.subnet_cidr
  project_name     = var.project_name
}

module "storage" {
  source = "./modules/storage"

  compartment_ocid        = var.compartment_ocid
  bucket_name             = var.tfstate_bucket_name
  project_name            = var.project_name
  create_bucket           = var.enable_tfstate_bucket
  create_artifacts_bucket = false
  create_import_bucket    = true # For importing Fedora images from automation_images
}

# Data source to get availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}
