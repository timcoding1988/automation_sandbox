packer {
  required_plugins {
    oracle = {
      source  = "github.com/hashicorp/oracle"
      version = ">= 1.0.0"
    }
  }
}

# Variables
variable "compartment_ocid" {
  type        = string
  description = "OCI compartment OCID where image will be created"
}

variable "subnet_ocid" {
  type        = string
  description = "Subnet OCID for the build instance"
}

variable "availability_domain" {
  type        = string
  description = "Availability domain for the build instance"
}

variable "oci_tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID"
  default     = env("OCI_TENANCY_OCID")
}

variable "oci_user_ocid" {
  type        = string
  description = "OCI user OCID"
  default     = env("OCI_USER_OCID")
}

variable "oci_fingerprint" {
  type        = string
  description = "OCI API key fingerprint"
  default     = env("OCI_FINGERPRINT")
}

variable "oci_key_file" {
  type        = string
  description = "Path to OCI API private key"
  default     = env("OCI_KEY_FILE")
}

variable "oci_region" {
  type        = string
  description = "OCI region"
  default     = "us-ashburn-1"
}

variable "img_sfx" {
  type        = string
  description = "Image name suffix for versioning"
  default     = "{{timestamp}}"
}

variable "base_image_ocid" {
  type        = string
  description = "OCID of the base Oracle Linux image"
  # Oracle Linux 8 - get latest from OCI console or use data source
}

# Source: OCI Compute Instance
source "oracle-oci" "image-builder" {
  # OCI Authentication - uses ~/.oci/config by default
  # Can override with access_cfg_file or individual vars

  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_ocid         = var.subnet_ocid

  # Use Oracle Linux 8 as base (CentOS Stream equivalent for OCI)
  base_image_ocid = var.base_image_ocid

  # Bare metal shape for nested virtualization
  # BM.Standard.E5.192 supports nested virt (E4.128 doesn't exist)
  shape = "BM.Standard.E5.192"

  # Image naming
  image_name = "image-builder-${var.img_sfx}"

  # SSH configuration
  ssh_username = "opc"

  # Instance configuration
  instance_name = "packer-image-builder-${var.img_sfx}"
}

# Build configuration
build {
  sources = ["source.oracle-oci.image-builder"]

  # Create working directory
  provisioner "shell" {
    inline = [
      "set -e",
      "sudo mkdir -p /var/tmp/automation_images",
      "sudo chown opc:opc /var/tmp/automation_images"
    ]
  }

  # Upload repository files
  provisioner "file" {
    source      = "${path.root}/../../"
    destination = "/var/tmp/automation_images/"
  }

  # Run setup script
  provisioner "shell" {
    inline = [
      "set -e",
      "chmod +x /var/tmp/automation_images/packer/image-builder/scripts/bootstrap.sh",
      "sudo /bin/bash /var/tmp/automation_images/packer/image-builder/scripts/bootstrap.sh"
    ]
  }

  # Output manifest
  post-processor "manifest" {
    output     = "${path.root}/manifest.json"
    strip_path = true
    custom_data = {
      img_sfx = var.img_sfx
      stage   = "image-builder"
    }
  }
}
