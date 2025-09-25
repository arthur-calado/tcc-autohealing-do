# terraform/monitoring.tf

resource "digitalocean_droplet" "monitoring" {
  name     = "${var.project_name}-monitoring"
  size     = "s-1vcpu-2gb"
  image    = var.image
  region   = var.region
  vpc_uuid = digitalocean_vpc.tcc_vpc.id
  ssh_keys = var.ssh_keys

  # AQUI ESTA A CORRECAO:
  # Adicionamos a linha "do_token = var.do_token" ao template principal
  # para que ele também receba a variável.
  user_data = templatefile("${path.module}/user_data_monitor.sh.tftpl", {
    prometheus_config = templatefile("${path.module}/prometheus.yml.tftpl", {
      do_token = var.do_token
    })
    rules_config = file("${path.module}/rules.yml.tftpl")
    do_token     = var.do_token # <-- A LINHA QUE FALTAVA
  })
}