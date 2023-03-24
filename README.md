# argocd-poc
Deploying Elasticsearch + Kibana through DigitalOcean + Terraform + Helm + ArgoCD + k3s

## Import SSH key

```shell
DIGITALOCEAN_TOKEN="..." # from https://cloud.digitalocean.com/account/api/tokens
KEY_NAME="argocd-poc"
PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub) # created with ssh-keygen
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
  -d "{\"name\":\"$KEY_NAME\",\"public_key\":\"$PUBLIC_KEY\"}" \
  "https://api.digitalocean.com/v2/account/keys"
```

## Create droplet

```shell
# assumes terraform in $PATH
terraform init && terraform apply -var "digitalocean_token=$DIGITALOCEAN_TOKEN"
```

## Provision

```shell
# get IP
EXTERNAL_IP=$(terraform show -json terraform.tfstate | jq -r '.values.root_module.resources[] | select(.address=="digitalocean_droplet.argocd-poc") | .values.ipv4_address')
# wait for SSH to be available
while ! nc -z $EXTERNAL_IP 22; do sleep 1; done
# configure user
scp ./scripts/000-configure-user.sh root@$EXTERNAL_IP:/tmp && ssh -t root@$EXTERNAL_IP 'bash /tmp/000-configure-user.sh'
# update droplet
scp ./scripts/001-update-droplet.sh root@$EXTERNAL_IP:/tmp && ssh -t root@$EXTERNAL_IP 'bash /tmp/001-update-droplet.sh'
# poweroff, sleep, powercycle
ssh root@$EXTERNAL_IP 'bash -c "poweroff"'
sleep 15 && ./scripts/002-power-cycle-droplet.sh
# wait for SSH to be available
while ! nc -z $EXTERNAL_IP 22; do sleep 1; done
# install k3s
scp ./scripts/003-install-k3s.sh brandon@$EXTERNAL_IP:/tmp && ssh -t brandon@$EXTERNAL_IP 'bash /tmp/003-install-k3s.sh'
# install dependencies
scp ./scripts/004-install-dependencies.sh brandon@$EXTERNAL_IP:/tmp && ssh -t brandon@$EXTERNAL_IP 'bash /tmp/004-install-dependencies.sh'
# deploy argocd
scp ./scripts/004-deploy-argocd.sh brandon@$EXTERNAL_IP:/tmp && ssh -t brandon@$EXTERNAL_IP 'bash /tmp/004-deploy-argocd.sh'
# deploy elk stack
scp ./scripts/005-deploy-elk-stack.sh brandon@$EXTERNAL_IP:/tmp && ssh -t brandon@$EXTERNAL_IP 'bash /tmp/005-deploy-elk-stack.sh'
# deploy docker registry
scp ./scripts/006-deploy-docker-registry.sh brandon@$EXTERNAL_IP:/tmp && ssh -t brandon@$EXTERNAL_IP 'bash /tmp/006-deploy-docker-registry.sh'
# build custom OCI image
scp ./scripts/007-build-custom-oci-image.sh brandon@$EXTERNAL_IP:/tmp && ssh -t brandon@$EXTERNAL_IP 'bash /tmp/007-build-custom-oci-image.sh'
# build deploy custom OCI image
scp ./scripts/008-deploy-custom-oci-image.sh brandon@$EXTERNAL_IP:/tmp && ssh -t brandon@$EXTERNAL_IP 'bash /tmp/008-deploy-custom-oci-image.sh'
```

## Using ArgoCD UI

```shell
# get argocd password (username is admin)
ssh brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl --namespace argocd get secret argocd-initial-admin-secret -o json | jq -r '.data.password' | base64 -d"'
# tunnel
ssh -L 8080:127.0.0.1:8080 brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/argocd-server -n argocd 8080:443"'
# go to argocd in browser at https://localhost:8080
```

## Using Kibana UI

```shell
# get kibana password (username is elastic)
ssh brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl --namespace elk get secret elasticsearch-master-credentials -o json | jq -r '.data.password' | base64 -d"'
# tunnel
ssh -L 5601:127.0.0.1:5601 brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/kibana-kibana -n elk 5601:5601"'
# go to kibana in browser at https://localhost:5601
```

## Using Elasticsearch API

```shell
# get kibana password (username is elastic)
ssh brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl --namespace elk get secret elasticsearch-master-credentials -o json | jq -r '.data.password' | base64 -d"'
# tunnel
ssh -L 9200:127.0.0.1:9200 brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/kibana-kibana -n elk 9200:9200"'
# use API at http://localhost:9200
```

## Using Docker registry

```shell
ssh -L 5000:127.0.0.1:5000 brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/docker-registry -n docker-registry 5000:5000"'
```

## Cleanup

```shell
terraform destroy -var "digitalocean_token=$DIGITALOCEAN_TOKEN"
```
