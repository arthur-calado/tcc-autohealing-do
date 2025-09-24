# terraform/firewall.tf

resource "digitalocean_firewall" "monitoring_fw" {
  name = "${var.project_name}-monitoring-fw"

  # A que Droplets esta firewall se aplica?
  # A todos os que tiverem a tag "monitoring"
  droplet_ids = [digitalocean_droplet.monitoring.id]

  # Regras de Entrada (Inbound)
  # O que permitimos que chegue AO nosso servidor

  # 1. Permitir acesso ao Prometheus (porta 9090) de qualquer IP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9090"
    source_addresses = ["0.0.0.0/0", "::/0"] # Qualquer IP (IPv4 e IPv6)
  }

  # 2. Permitir acesso ao Alertmanager (porta 9093) de qualquer IP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9093"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # 3. Permitir acesso SSH (porta 22) para podermos ligar-nos ao Droplet
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Regras de Saída (Outbound)
  # O que o nosso servidor tem permissão para aceder no exterior
  # Por defeito, permitimos tudo para que ele possa, por exemplo,
  # descarregar imagens do Docker.

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# 🔹 Firewall para os Droplets Web
resource "digitalocean_firewall" "web_fw" {
  name = "${var.project_name}-web-fw"

  # Aplica esta firewall a todos os droplets com a tag "web"
  tags = [digitalocean_tag.web.name]

  # Regras de Entrada:
  # 1. Permitir tráfego vindo APENAS do nosso Load Balancer na porta da app
  inbound_rule {
    protocol              = "tcp"
    port_range            = "8080"
    source_load_balancer_uids = [digitalocean_loadbalancer.lb.id]
  }

  # 2. Permitir acesso SSH de qualquer lugar
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Regras de Saída (permitir tudo)
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}