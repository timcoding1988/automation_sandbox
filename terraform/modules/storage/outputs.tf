output "namespace" {
  description = "Object Storage namespace"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "tfstate_bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = var.create_bucket ? oci_objectstorage_bucket.tfstate[0].name : null
}

output "artifacts_bucket_name" {
  description = "Name of the artifacts bucket"
  value       = var.create_artifacts_bucket ? oci_objectstorage_bucket.artifacts[0].name : null
}

output "import_bucket_name" {
  description = "Name of the image import bucket"
  value       = var.create_import_bucket ? oci_objectstorage_bucket.import[0].name : null
}
