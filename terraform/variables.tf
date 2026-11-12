variable "pve_endpoint" {
  type    = string
  default = "https://100.75.81.69:8006/"
}

variable "pve_api_token" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key from kdell for passwordless Ansible access"
}

variable "gateway_ip" {
  type    = string
  default = "192.168.0.1"
}
