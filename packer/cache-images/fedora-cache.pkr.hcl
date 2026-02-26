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

variable "fedora_release" {
  type        = string
  description = "Fedora release version"
  default     = "43"
}

variable "base_image_ocid" {
  type        = string
  description = "OCID of the Fedora base image (built from base-images)"
}

# Source: OCI Compute Instance
source "oracle-oci" "fedora-cache" {
  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_ocid         = var.subnet_ocid

  # Use the base image we built
  base_image_ocid = var.base_image_ocid

  # Use larger instance for faster package installation
  shape = "VM.Standard.E5.Flex"
  shape_config {
    ocpus         = 4
    memory_in_gbs = 16
  }

  # Image naming
  image_name = "fedora-cache-${var.img_sfx}"

  # SSH configuration
  ssh_username = "opc"

  # Instance configuration
  instance_name = "packer-fedora-cache-${var.img_sfx}"
}

# Build configuration
build {
  sources = ["source.oracle-oci.fedora-cache"]

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
      "chmod +x /var/tmp/automation_images/packer/cache-images/scripts/fedora-cache-setup.sh",
      "sudo /bin/bash /var/tmp/automation_images/packer/cache-images/scripts/fedora-cache-setup.sh"
    ]
    environment_vars = [
      "PACKER_BUILD_NAME=${source.name}"
    ]
  }

  # Output manifest
  post-processor "manifest" {
    output     = "${path.root}/manifest.json"
    strip_path = true
    custom_data = {
      img_sfx        = var.img_sfx
      stage          = "cache"
      fedora_release = var.fedora_release
    }
  }
}
