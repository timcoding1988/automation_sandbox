terraform {
  required_version = ">= 1.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0"
    }
  }

  # Optional: Use OCI Object Storage for state
  # Uncomment and configure for production use
  # backend "s3" {
  #   bucket                      = "oci-images-tfstate"
  #   key                         = "terraform.tfstate"
  #   region                      = "us-ashburn-1"
  #   endpoint                    = "https://<namespace>.compat.objectstorage.us-ashburn-1.oraclecloud.com"
  #   skip_region_validation      = true
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   force_path_style            = true
  # }
}

provider "oci" {
  # Configuration via environment variables or ~/.oci/config
  # OCI_TENANCY_OCID, OCI_USER_OCID, OCI_FINGERPRINT, OCI_PRIVATE_KEY_PATH, OCI_REGION
}
