#!/bin/bash

set -e

log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") - $*"
}

call_api() {
    local endpoint="$1"
    local method="$2"
    local data="$3"
    local api_base_url="https://api.vultr.com/v2"
    local auth_header="Authorization: Bearer ${VULTR_API_KEY}"
    local content_type_header="Content-Type: application/json"
    curl -s "${api_base_url}${endpoint}" \
        -H "${auth_header}" \
        ${method:+-X "${method}"} \
        ${data:+-d "${data}"} \
        ${data:+-H "${content_type_header}"}
}

function vultr_get_ssh_key_id_by_name() {
  local name="$1"
  local response=$(call_api "/ssh-keys" "GET")
  echo "${response}" | jq -r "first(.ssh_keys[] | select(.name == \"${name}\")) | .id"
}

function vultr_create_ssh_key() {
  local name="$1"
  local ssh_key="$2"
  local json_payload=$(cat <<- EOM
{
    "name": "${name}",
    "ssh_key": "${ssh_key}"
}
EOM
  )
  call_api "/ssh-keys" "POST" "${json_payload}"
}

function vultr_get_instance_id_by_label() {
  local label="$1"
  local instances=$(call_api "/instances" "GET")
  echo "${instances}" | jq -r "first(.instances[] | select(.label == \"${label}\")) | .id"
}

function vultr_get_instance_external_ip_by_label() {
  local label="$1"
  local instances=$(call_api "/instances" "GET")
  echo "${instances}" | jq -r "first(.instances[] | select(.label == \"${label}\")) | .main_ip"
}

function vultr_get_os_id_by_name() {
    local name="$1"
    local response=$(call_api "/os" "GET")
    echo "${response}" | jq -r "first(.os[] | select(.name == \"${name}\")) | .id"
}

function vultr_create_instance() {
  local label="$1"
  local region="$2"
  local plan="$3"
  local os_name="$4"
  local os_id=$(vultr_get_os_id_by_name "$os_name")
  local ssh_key_id="$5"
  local json_payload=$(cat <<- EOM
{
    "label": "${label}",
    "region": "${region}",
    "plan": "${plan}",
    "os_id": ${os_id},
    "sshkey_id": ["${ssh_key_id}"]
}
EOM
    )
    call_api "/instances" "POST" "${json_payload}"
}
