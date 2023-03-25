#!/bin/bash
# exit on errors
set -e
# load kubeconfig
export KUBECONFIG=~/.kube/config
# deploy dashboard
kubectl create namespace kubernetes-dashboard
argocd app create kubernetes-dashboard --repo "https://github.com/kubernetes/dashboard.git" --revision "42deb6b32a27296ac47d1f9839a68fab6053e5fc" --path ./aio/deploy/recommended --dest-namespace kubernetes-dashboard --dest-server https://kubernetes.default.svc --upsert
argocd app sync kubernetes-dashboard && argocd app wait kubernetes-dashboard
# create admin user
ADMIN_USER_YAML=$(
cat <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
)
echo "$ADMIN_USER_YAML" | kubectl -n kubernetes-dashboard apply -f /dev/stdin
# print token
TOKEN=$(kubectl -n kubernetes-dashboard create token admin-user)
echo "token: $TOKEN"
