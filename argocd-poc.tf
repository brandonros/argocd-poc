variable "digitalocean_token" {}

provider "digitalocean" {
  token = var.digitalocean_token
}

data "digitalocean_ssh_key" "argocd-poc" {
  name = "argocd-poc"
}

resource "digitalocean_droplet" "argocd-poc" {
  image = "debian-11-x64"
  name = "argocd-poc"
  region = "nyc3"
  size = "s-2vcpu-4gb"
  ssh_keys = [data.digitalocean_ssh_key.argocd-poc.fingerprint]
}
