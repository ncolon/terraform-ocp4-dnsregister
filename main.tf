resource "null_resource" "dependency" {
  triggers = {
    all_dependencies = "${join(",", var.dependson)}"
  }
}

locals {
  # assume the default reverse zone is a Class C
  default_reverse_zone = "${format("%s.in-addr.arpa", join(".", reverse(slice(split(".", element(var.dns_private_ip,0)), 0, 3))))}"
  reverse_zone = "${var.reverse_zone != "" ? var.reverse_zone : local.default_reverse_zone}"
  forward_zone = "${var.cluster_name}.${var.private_domain}"
  loadbalancer_hostnames_apps = ["*.apps"]
  loadbalancer_ips_apps = ["${var.applb_private_ip}"]
  loadbalancer_hostnames_noapps = ["api", "api-int"]
  loadbalancer_ips_noapps = ["${var.controllb_private_ip}","${var.controllb_private_ip}"]
  bootstrap_hostname = ["bootstrap"]
}


data "template_file" "etcd_hostname" {
  count = "${var.control_plane["count"]}"
  template = "${format("etcd-%d", count.index)}"
}

data "template_file" "etcd_srv_hostname" {
  count = 1
  template = "_etcd-server-ssl._tcp"
}

data "template_file" "control_plane_hostname" {
  count = "${var.control_plane["count"]}"
  template = "${format("master%02d", count.index + 1)}"
}

data "template_file" "worker_hostname" {
  count = "${var.worker["count"]}"
  template = "${format("worker%02d", count.index + 1)}"
}

data "template_file" "etcd_a_records" {
  count = "${var.control_plane["count"]}"
  template = "${format("{'type': 'A', 'name': '%s', 'value': '%s', 'zone': '${local.forward_zone}'}",
                      "${element(data.template_file.etcd_hostname.*.rendered, count.index)}",
                      "${element(var.control_plane_private_ip, count.index)}")}"
}

data "template_file" "master_a_records" {
  count = "${var.control_plane["count"]}"
  template = "${format("{'type': 'A', 'name': '%s', 'value': '%s', 'zone': '${local.forward_zone}'}",
                      "${element(data.template_file.control_plane_hostname.*.rendered, count.index)}",
                      "${element(var.control_plane_private_ip, count.index)}")}"
}

data "template_file" "worker_a_records" {
  count = "${var.worker["count"]}"
  template = "${format("{'type': 'A', 'name': '%s', 'value': '%s', 'zone': '${local.forward_zone}'}",
                      "${element(data.template_file.worker_hostname.*.rendered, count.index)}",
                      "${element(var.worker_ip_address, count.index)}")}"
}


data "template_file" "appslb_a_records" {
  count = 3
  template = "${format("{'type': 'A', 'name': '%s', 'value': '%s', 'zone': '${local.forward_zone}'}",
                      element(local.loadbalancer_hostnames_apps, count.index),
                      element(local.loadbalancer_ips_apps, count.index))}"
}

data "template_file" "controllb_a_records" {
  count = 3
  template = "${format("{'type': 'A', 'name': '%s', 'value': '%s', 'zone': '${local.forward_zone}'}",
                      element(local.loadbalancer_hostnames_noapps, count.index),
                      element(local.loadbalancer_ips_noapps, count.index))}"
}

data "template_file" "bootstrap_a_records" {
  count = 1
  template = "${format("{'type': 'A', 'name': '%s', 'value': '%s', 'zone': '${local.forward_zone}'}",
                      element(local.bootstrap_hostname, count.index),
                      element(var.bootstrap_ip_address, count.index))}"
}

data "template_file" "worker_ptr_records" {
  count = "${var.worker["count"]}"
  template = "${format("{'type': 'PTR', 'name': '%s', 'value': '%s', 'zone': '${local.reverse_zone}.'}",
                      "${element(slice(reverse(split(".", element(var.worker_ip_address, count.index))), 0,1),0)}",
                      "${element(data.template_file.worker_hostname.*.rendered, count.index)}.${local.forward_zone}.")}"
}

data "template_file" "master_ptr_records" {
  count = "${var.control_plane["count"]}"
  template = "${format("{'type': 'PTR', 'name': '%s', 'value': '%s', 'zone': '${local.reverse_zone}.'}",
                      "${element(slice(reverse(split(".", element(var.control_plane_private_ip, count.index))), 0,1),0)}",
                      "${element(data.template_file.control_plane_hostname.*.rendered, count.index)}.${local.forward_zone}.")}"
}

data "template_file" "bootstrap_ptr_records" {
  count = 1
  template = "${format("{'type': 'PTR', 'name': '%s', 'value': '%s', 'zone': '${local.reverse_zone}.'}",
                      "${element(slice(reverse(split(".", element(var.bootstrap_ip_address, count.index))), 0,1),0)}",
                      "${element(local.bootstrap_hostname, count.index)}.${local.forward_zone}.")}"
}

data "template_file" "etdc_srv_records_values" {
  count = "${var.control_plane["count"]}"
  template = "0 10 2380 ${element(data.template_file.etcd_hostname.*.rendered, count.index)}.${local.forward_zone}."
}
data "template_file" "etcd_srv_records" {
  count = 1
  template = "${format("{'type': 'SRV', 'name': '%s', 'value': '%s', 'zone': '${local.forward_zone}.'}",
                      "${element(data.template_file.etcd_srv_hostname.*.rendered,count.index)}",
                      "${join(",", formatlist("%s",data.template_file.etdc_srv_records_values.*.rendered))}")}"
}

data "template_file" "controllb_ptr_records" {
  count = 1
  template = "${format("{'type': 'PTR', 'name': '%s', 'value': '%s', 'zone': '${local.reverse_zone}.'}",
                      "${element(slice(reverse(split(".", var.controllb_private_ip)), 0, 1),0)}",
                      "${join(",", formatlist("%s.%s.", local.loadbalancer_hostnames_noapps, local.forward_zone))}")}"
}

data "template_file" "records" {
  template=<<EOF
[${join(",", concat(
data.template_file.etcd_a_records.*.rendered,
data.template_file.master_a_records.*.rendered,
data.template_file.worker_a_records.*.rendered,
data.template_file.appslb_a_records.*.rendered,
data.template_file.controllb_a_records.*.rendered,
data.template_file.bootstrap_a_records.*.rendered,
data.template_file.worker_ptr_records.*.rendered,
data.template_file.master_ptr_records.*.rendered,
data.template_file.controllb_ptr_records.*.rendered,
data.template_file.bootstrap_ptr_records.*.rendered,
data.template_file.etcd_srv_records.*.rendered,
))}]
EOF
}

module "runplaybooks" {
  source = "github.com/ibm-cloud-architecture/terraform-ansible-runplaybooks.git"

  ansible_playbook_dir = "${path.module}/playbooks"
  ansible_playbooks = [
    "playbooks/configure_dns.yaml"
  ]

  ssh_user           = "${var.ssh_user}"
  ssh_password       = "${var.ssh_password}"
  ssh_private_key    = "${var.ssh_private_key}"

  bastion_ip_address       = "${var.bastion_ip_address}"
  bastion_ssh_user         = "${var.ssh_user}"
  bastion_ssh_password     = "${var.ssh_password}"
  bastion_ssh_private_key  = "${var.ssh_private_key}"

  node_ips = "${var.dns_private_ip}"
  node_hostnames = "${var.dns_private_ip}"

  dependson = [
      "${null_resource.dependency.id}",
  ]

  triggerson = {
    node_ips = "${join(",", var.dns_private_ip)}"
  }

  ansible_vars       = {
    "dns_key_name"       = "${var.dns_key_name}"
    "dns_key_algorithm"  = "${var.dns_key_algorithm}"
    "dns_key_secret"     = "${var.dns_key_secret}"
    "public_dns_servers" = "${join(",", var.public_dns_servers)}"
    "forward_zone"       = "${local.forward_zone}"
    "reverse_zone"       = "${local.reverse_zone}"
    "dns_private_ip"     = "${element(var.dns_private_ip,0)}"
    "records"            = "${base64encode(data.template_file.records.rendered)}"
  }
  # ansible_verbosity = "-vvv"
}
