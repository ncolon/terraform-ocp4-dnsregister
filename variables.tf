variable "dependson" {
  type    = "list"
  default = []
}

variable "bastion_ip_address" {}
variable "ssh_user" {}
variable "ssh_password" {}
variable "ssh_private_key" {}

variable "dns_public_ip" {}
variable "dns_private_ip" {}

variable "public_dns_servers" {
  type    = "list"
  default = ["8.8.8.8", "8.8.4.4"]
}
variable "private_domain" {}

variable "dns_key_name_internal" {}
variable "dns_key_name_external" {}
variable "dns_key_algorithm" {}
variable "dns_key_secret_internal" {}
variable "dns_key_secret_external" {}
variable "dns_record_ttl" {
  default = 300
}
variable "reverse_zone" {
  default = ""
}

variable "cluster_name" {}

variable "bootstrap_complete" {
  default = "false"
}

variable "control_plane" {
  type    = "map"
  default = {}
}

variable "worker" {
  type    = "map"
  default = {}
}

variable "worker_ip_address" {
  type    = "list"
  default = []
}

variable "control_plane_private_ip" {
  type    = "list"
  default = []
}

variable "bootstrap_ip_address" {}

variable "applb_private_ip" {}

variable "controllb_private_ip" {}

variable "applb_public_ip" {}

variable "controllb_public_ip" {}

