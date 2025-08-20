# 🔹 Tag para o banco
resource "digitalocean_tag" "db" {
  name = "${var.project_name}-db"
}

# 🔹 Tag para os webservers
resource "digitalocean_tag" "web" {
  name = "${var.project_name}-web"
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# 🔹 Cria SEMPRE um VPC exclusivo para este projeto
resource "digitalocean_vpc" "tcc_vpc" {
  name     = "${var.project_name}-vpc-${random_string.suffix.result}"
  region   = var.region
  ip_range = "10.10.0.0/16"   # range custom, evita confusão com default
  lifecycle {
    create_before_destroy = true
  }
}

# 🔹 Droplet do banco (usando SEMPRE o VPC custom)
resource "digitalocean_droplet" "db" {
  name     = "${var.project_name}-db"
  region   = var.region
  size     = var.db_size
  image    = var.image
  vpc_uuid = digitalocean_vpc.tcc_vpc.id   # <── sempre no VPC custom
  ipv6     = false
  ssh_keys = var.ssh_keys
  tags     = [digitalocean_tag.db.id]

  user_data = file("${path.module}/user_data_db.sh")
}

# 🔹 Droplets Web
resource "digitalocean_droplet" "web" {
  count    = var.web_count
  name     = "${var.project_name}-web-${count.index}"
  region   = var.region
  size     = var.web_size
  image    = var.image
  vpc_uuid = digitalocean_vpc.tcc_vpc.id   # <── sempre no VPC custom
  ipv6     = false
  ssh_keys = var.ssh_keys
  tags     = [digitalocean_tag.web.id]

  user_data = templatefile("${path.module}/user_data_web.sh", {
    db_host = digitalocean_droplet.db.ipv4_address_private
  })
}

# 🔹 Load Balancer no VPC custom
resource "digitalocean_loadbalancer" "lb" {
  name     = "${var.project_name}-lb"
  region   = var.region
  vpc_uuid = digitalocean_vpc.tcc_vpc.id   # <── sempre no VPC custom

  redirect_http_to_https = false

  forwarding_rule {
    entry_protocol  = "http"
    entry_port      = 80
    target_protocol = "http"
    target_port     = 8080
  }

  healthcheck {
    protocol               = "http"
    port                   = 8080
    path                   = "/health"
    check_interval_seconds = 5
    response_timeout_seconds = 3
    unhealthy_threshold    = 2
    healthy_threshold      = 2
  }

  droplet_tag = digitalocean_tag.web.name
}
