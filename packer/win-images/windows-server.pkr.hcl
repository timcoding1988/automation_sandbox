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

variable "winrm_password" {
  type        = string
  description = "Password for WinRM authentication"
  sensitive   = true
  default     = ""
}

variable "debug_mode" {
  type        = bool
  description = "Enable debug mode - extends timeout to 2 hours for manual troubleshooting"
  default     = false
}

# Source: OCI Compute Instance
source "oracle-oci" "windows-server" {
  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_ocid         = var.subnet_ocid

  # Windows Server 2022 from OCI marketplace
  base_image_ocid = var.base_image_ocid

  # VM shape for Windows
  shape = "VM.Standard.E5.Flex"
  shape_config {
    ocpus         = 4
    memory_in_gbs = 32
  }

  # Image naming
  image_name = "windows-server-${var.img_sfx}"

  # WinRM communicator for Windows (HTTPS like automation_images)
  communicator            = "winrm"
  winrm_username          = "opc"
  winrm_password          = var.winrm_password
  winrm_insecure          = true
  winrm_use_ssl           = true
  winrm_port              = 5986
  winrm_timeout           = var.debug_mode ? "2h" : "30m"
  pause_before_connecting = "4m"  # Give cloudbase-init time to configure WinRM

  # User data to configure WinRM (cloudbase-init format for OCI Windows)
  # The script must set password for opc user and enable WinRM
  user_data = base64encode(templatefile("${path.cwd}/packer/win-images/scripts/bootstrap.ps1.tpl", {
    winrm_password = var.winrm_password
  }))

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
