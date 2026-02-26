output "vcn_id" {
  description = "OCID of the VCN"
  value       = module.network.vcn_id
}

output "subnet_id" {
  description = "OCID of the public subnet for image building"
  value       = module.network.subnet_id
}

output "availability_domains" {
  description = "List of availability domains"
  value       = data.oci_identity_availability_domains.ads.availability_domains[*].name
}

output "object_storage_namespace" {
  description = "Object Storage namespace"
  value       = module.storage.namespace
}

output "tfstate_bucket" {
  description = "Terraform state bucket name"
  value       = module.storage.tfstate_bucket_name
}

output "import_bucket" {
  description = "Image import bucket name"
  value       = module.storage.import_bucket_name
}
