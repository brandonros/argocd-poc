#!/bin/bash
set -e
DROPLET_ID=$(terraform show -json terraform.tfstate | jq -r '.values.root_module.resources[] | select(.address=="digitalocean_droplet.argocd-poc") | .values.id')
# power on droplet
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
  -d '{"type":"power_on"}' \
  "https://api.digitalocean.com/v2/droplets/$DROPLET_ID/actions"
# sleep
sleep 15
