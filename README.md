# argocd-poc
Building + deploying OCI images + dependencies through DigitalOcean + Ansible + Helm + ArgoCD + k3s + Kaniko

## Pre-requisites

```shell
# install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# install ansible
brew install ansible
```

## Provision droplet

```shell
# assumes ansible in PATH
# assumes DIGITALOCEAN_TOKEN environment variable set
# assumes ssh public key already generated at ~/.ssh/id_rsa.pub
ansible-playbook --ask-become -vvv ansible/playbook.yaml
```

## Provision application + dependencies

```shell
# get IP
EXTERNAL_IP='...' # get from ansible output?
# build app custom OCI image + deploy app custom OCI image as argocd app through helm charts
scp ./scripts/build-custom-oci-image.sh brandon@$EXTERNAL_IP:/tmp && ssh -t brandon@$EXTERNAL_IP 'bash /tmp/build-custom-oci-image.sh' && scp ./scripts/deploy-custom-oci-image.sh brandon@$EXTERNAL_IP:/tmp && ssh -t brandon@$EXTERNAL_IP 'bash /tmp/deploy-custom-oci-image.sh'
```

## Using ArgoCD UI

```shell
# get argocd password (username is admin)
ssh brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl --namespace argocd get secret argocd-initial-admin-secret -o json | jq -r '.data.password' | base64 -d"'
# tunnel
ssh -L 8080:127.0.0.1:8080 brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/argocd-server -n argocd 8080:443"'
# go to argocd in browser at https://localhost:8080
```

## Using Kubernetes Dashboard

```shell
# tunnel
ssh -L 8443:127.0.0.1:8443 brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/kubernetes-dashboard -n kubernetes-dashboard 8443:443"'
# open browser to https://localhost:8443
```

## Using Elasticsearch API

```shell
# get kibana password (username is elastic)
ssh brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl --namespace elk get secret elasticsearch-master-credentials -o json | jq -r '.data.password' | base64 -d"'
# tunnel
ssh -L 9200:127.0.0.1:9200 brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/kibana-kibana -n elk 9200:9200"'
# use API at https://localhost:9200
```

## Using Kibana UI

```shell
# get kibana password (username is elastic)
ssh brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl --namespace elk get secret elasticsearch-master-credentials -o json | jq -r '.data.password' | base64 -d"'
# tunnel
ssh -L 5601:127.0.0.1:5601 -N brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/kibana-kibana -n elk 5601:5601"'
# go to kibana in browser at http://localhost:5601
```

## Using Docker registry

```shell
# tunnel
ssh -L 5000:127.0.0.1:5000 brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/docker-registry -n docker-registry 5000:5000"'
```

## Using Custom OCI image application

```shell
# tunnel
ssh -L 3000:127.0.0.1:3000 brandon@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/test -n test 3000:3000"'
# test connecitivty
curl -X POST -H 'Content-Type: application/json' http://localhost:3000/index -d '{
  "indexName": "test",
  "messageId": 1,
  "message": {
    "foo": "bar"
  }
}'
```

## Debugging DNS resolution

```shell
kubectl run test-dns-busybox -i --tty --image=busybox:1.36.0 --rm --restart=Never -- nslookup elasticsearch-master-headless.elk.svc.cluster.local
```
