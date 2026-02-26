# OCI Object Storage Module
# Creates bucket for Terraform state and image artifacts

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

resource "oci_objectstorage_bucket" "tfstate" {
  count = var.create_bucket ? 1 : 0

  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = var.bucket_name
  access_type    = "NoPublicAccess"

  versioning = "Enabled"

  metadata = {
    purpose = "terraform-state"
    project = var.project_name
  }
}

# Optional: Create a bucket for QEMU image uploads
resource "oci_objectstorage_bucket" "artifacts" {
  count = var.create_artifacts_bucket ? 1 : 0

  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "${var.project_name}-artifacts"
  access_type    = "NoPublicAccess"

  metadata = {
    purpose = "image-artifacts"
    project = var.project_name
  }
}

# Bucket for importing Fedora images from automation_images
resource "oci_objectstorage_bucket" "import" {
  count = var.create_import_bucket ? 1 : 0

  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "oci-images-import"
  access_type    = "NoPublicAccess"

  # Auto-delete uploaded images after 7 days to save costs
  # (they're imported as custom images, so the upload is no longer needed)
  metadata = {
    purpose = "fedora-image-import"
    project = var.project_name
  }
}
