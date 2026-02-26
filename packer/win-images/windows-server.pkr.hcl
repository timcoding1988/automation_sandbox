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
  description = "OCID of the Windows Server 2022 image from OCI marketplace"
}

# Source: OCI Compute Instance (Bare Metal for Hyper-V)
source "oracle-oci" "windows-server" {
  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_ocid         = var.subnet_ocid

  # Windows Server 2022 from OCI marketplace
  base_image_ocid = var.base_image_ocid

  # VM shape for Windows (bare metal not compatible with Windows images)
  # Note: Hyper-V/WSL requires bare metal, but image build can use VM
  shape = "VM.Standard.E5.Flex"
  shape_config {
    ocpus         = 4
    memory_in_gbs = 32
  }

  # Image naming
  image_name = "windows-server-${var.img_sfx}"

  # WinRM communicator for Windows
  communicator   = "winrm"
  winrm_username = "opc"
  winrm_insecure = true
  winrm_use_ssl  = true
  winrm_timeout  = "30m"

  # User data to configure WinRM
  user_data_file = "${path.root}/scripts/bootstrap.ps1"

  # Instance configuration
  instance_name = "packer-windows-server-${var.img_sfx}"
}

# Build configuration
build {
  sources = ["source.oracle-oci.windows-server"]

  # Create working directory
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'stop'",
      "New-Item -Path 'c:\\' -Name 'temp' -ItemType 'directory' -Force",
      "New-Item -Path 'c:\\temp' -Name 'automation_images' -ItemType 'directory' -Force"
    ]
  }

  # Upload repository files
  provisioner "file" {
    source      = "${path.root}/../../"
    destination = "c:\\temp\\automation_images\\"
  }

  # Run setup script
  provisioner "powershell" {
    inline = [
      "c:\\temp\\automation_images\\packer\\win-images\\scripts\\setup.ps1"
    ]
  }

  # Reboot after installing features
  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  # Run finalization script
  provisioner "powershell" {
    inline = [
      "c:\\temp\\automation_images\\packer\\win-images\\scripts\\finalize.ps1"
    ]
  }

  # Output manifest
  post-processor "manifest" {
    output     = "${path.root}/manifest.json"
    strip_path = true
    custom_data = {
      img_sfx = var.img_sfx
      stage   = "windows"
    }
  }
}
