variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Região da DO"
  type        = string
  default     = "nyc2"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "tcc-autohealing"
}

variable "web_count" {
  description = "Número de droplets web"
  type        = number
  default     = 2
}

variable "web_size" {
  description = "Tamanho do droplet web"
  type        = string
  default     = "s-1vcpu-512mb-10gb"
}

variable "db_size" {
  description = "Tamanho do droplet do banco"
  type        = string
  default     = "s-1vcpu-512mb-10gb"
}

variable "ssh_keys" {
  description = "Lista de IDs ou fingerprints de SSH Keys a anexar aos droplets"
  type        = list(string)
  default     = []
}

variable "my_ip" {
  description = "Seu IP público para liberar SSH (opcional). Ex: 1.2.3.4/32"
  type        = string
  default     = "45.4.61.152/32"
}

variable "image" {
  description = "Imagem base"
  type        = string
  default     = "ubuntu-24-04-x64"
}
