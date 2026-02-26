# OCI Network Module
# Creates VCN, subnet, and security lists for image building

resource "oci_core_vcn" "image_builder" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${var.project_name}-vcn"
  dns_label      = replace(var.project_name, "-", "")
}

resource "oci_core_internet_gateway" "image_builder" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.image_builder.id
  display_name   = "${var.project_name}-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.image_builder.id
  display_name   = "${var.project_name}-public-rt"

  route_rules {
    network_entity_id = oci_core_internet_gateway.image_builder.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

resource "oci_core_security_list" "image_builder" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.image_builder.id
  display_name   = "${var.project_name}-seclist"

  # Allow all egress
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # SSH access
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # WinRM HTTP (for Windows provisioning)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 5985
      max = 5985
    }
  }

  # WinRM HTTPS (for Windows provisioning)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 5986
      max = 5986
    }
  }

  # ICMP for network diagnostics
  ingress_security_rules {
    protocol = "1" # ICMP
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.image_builder.id
  cidr_block                 = var.subnet_cidr
  display_name               = "${var.project_name}-public-subnet"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.image_builder.id]
  prohibit_public_ip_on_vnic = false
}
