locals {
  k3s_nodes = {
    "k3s-control-1" = { vmid = 210, ip = "192.168.0.210/24", cores = 2, memory = 3072, disk = 15 }
    "k3s-worker-1"  = { vmid = 211, ip = "192.168.0.211/24", cores = 2, memory = 2048, disk = 12 }
    "k3s-worker-2"  = { vmid = 212, ip = "192.168.0.212/24", cores = 2, memory = 2048, disk = 12 }
  }
}

resource "proxmox_virtual_environment_container" "k3s_cluster" {
  for_each  = local.k3s_nodes
  node_name = "pve"
  vm_id     = each.value.vmid

  unprivileged  = true
  start_on_boot = true
  started       = true

  features {
    nesting = true
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
    swap      = 0
  }

  disk {
    datastore_id = "local-nvme"
    size         = each.value.disk
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = each.key
    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.gateway_ip
      }
    }
    dns {
      servers = ["1.1.1.1", "8.8.8.8"]
    }
    user_account {
      keys = [var.ssh_public_key]
    }
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    type             = "debian"
  }
}
