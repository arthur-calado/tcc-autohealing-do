# 🔹 Load Balancer
output "lb_ip" {
  value       = digitalocean_loadbalancer.lb.ip
  description = "IP público do Load Balancer"
}

# 🔹 DB (IP privado)
output "db_private_ip" {
  value       = digitalocean_droplet.db.ipv4_address_private
  description = "IP privado do banco de dados"
}

# 🔹 Webs (IPs privados)
output "web_private_ips" {
  value       = [for d in digitalocean_droplet.web : d.ipv4_address_private]
  description = "Lista de IPs privados dos web servers"
}

# 🔹 VPC Custom (ID)
output "vpc_id" {
  value       = digitalocean_vpc.tcc_vpc.id
  description = "ID do VPC custom usado na infraestrutura"
}

# 🔹 VPC Custom (CIDR)
output "vpc_cidr" {
  value       = digitalocean_vpc.tcc_vpc.ip_range
  description = "Faixa de rede privada (CIDR) do VPC custom"
}
