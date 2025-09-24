# terraform/monitoring.tf

# Droplet para rodar o Prometheus, Alertmanager e o Healer
resource "digitalocean_droplet" "monitoring" {
  name     = "${var.project_name}-monitoring"
  size     = "s-1vcpu-2gb" # Recomendado um pouco mais de memória
  image    = var.image
  region   = var.region
  vpc_uuid = digitalocean_vpc.tcc_vpc.id
  ssh_keys = var.ssh_keys

  # Usamos o script de user_data para provisionar tudo
  user_data = file("${path.module}/user_data_monitor.sh")
} 