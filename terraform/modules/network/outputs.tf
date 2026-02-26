output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.image_builder.id
}

output "subnet_id" {
  description = "OCID of the public subnet"
  value       = oci_core_subnet.public.id
}

output "security_list_id" {
  description = "OCID of the security list"
  value       = oci_core_security_list.image_builder.id
}

output "internet_gateway_id" {
  description = "OCID of the internet gateway"
  value       = oci_core_internet_gateway.image_builder.id
}
