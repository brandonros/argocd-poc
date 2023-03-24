#!/bin/bash
set -e
# install k3s
curl -sfL https://get.k3s.io | sh -
# configure KUBECONFIG
export KUBECONFIG=~/.kube/config
mkdir ~/.kube 2> /dev/null
sudo k3s kubectl config view --raw > "$KUBECONFIG"
chmod 600 "$KUBECONFIG"
