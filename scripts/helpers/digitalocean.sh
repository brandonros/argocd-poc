#!/bin/sh

function digitalocean_get_ssh_key_id_by_name() {
  NAME=$1
  SSH_KEYS=$(curl --fail \
    --silent \
    -X GET \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
    "https://api.digitalocean.com/v2/account/keys")
  SSH_KEY_ID=$(echo "$SSH_KEYS" | jq --arg NAME "$NAME" -r '.ssh_keys[] | select(.name==$NAME) | .id')
  if [ -z "$SSH_KEY_ID" ]
  then
    echo "null"
  else
    echo "$SSH_KEY_ID"
  fi
}

function digitalocean_get_droplet_id_by_name() {
  NAME=$1
  DROPLETS=$(curl --fail \
    --silent \
    -X GET \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
    "https://api.digitalocean.com/v2/droplets")
  DROPLET_ID=$(echo "$DROPLETS" | jq --arg NAME "$NAME" -r '.droplets[] | select(.name==$NAME) | .id')
  if [ -z "$DROPLET_ID" ]
  then
    echo "null"
  else
    echo "$DROPLET_ID"
  fi
}

function digitalocean_get_droplet_external_ip_by_name() {
  NAME=$1
  DROPLETS=$(curl --fail \
    --silent \
    -X GET \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
    "https://api.digitalocean.com/v2/droplets")
  EXTERNAL_IP=$(echo "$DROPLETS" | jq --arg NAME "$NAME" -r '.droplets[] | select(.name==$NAME) | .networks.v4[] | select(.type=="public") | .ip_address')
  if [ -z "$EXTERNAL_IP" ]
  then
    echo "null"
  else
    echo "$EXTERNAL_IP"
  fi
}

function digitalocean_create_ssh_key() {
  NAME=$1
  PUBLIC_KEY=$2
  REQUEST_BODY=$(cat <<EOF
{
  "name": "$NAME",
  "public_key": "$PUBLIC_KEY"
}
EOF
)
  curl --fail \
    --silent \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
    -d "$REQUEST_BODY" \
    "https://api.digitalocean.com/v2/account/keys"
}

function digitalocean_create_droplet() {
  NAME=$1
  SIZE=$2
  REGION=$3
  IMAGE=$4
  SSH_KEY_ID=$5
  REQUEST_BODY=$(cat <<EOF
{
  "name": "$NAME",
  "region": "$REGION",
  "size": "$SIZE",
  "image": "$IMAGE",
  "ssh_keys": [$SSH_KEY_ID],
  "backups": false,
  "ipv6": false,
  "monitoring": false,
  "tags": [],
  "user_data": ""
}
EOF
)
  curl --fail \
    --silent \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
    -d "$REQUEST_BODY" \
    "https://api.digitalocean.com/v2/droplets"
}
