#!/bin/sh

. config.sh
. digital-ocean-api.sh

# get EXTERNAL_IP
DROPLET_ID=$(digitalocean_get_droplet_id_by_name "$DROPLET_NAME")
EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_id "$DROPLET_ID")
# droplet deploy argocd app (kubernetes-dashboard)
COMMAND=$(cat <<-'EOF'
set -e
export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
YAML=$(cat <<-'INNER_EOF'
kind: Namespace
apiVersion: v1
metadata:
  name: kubernetes-dashboard
  labels:
    name: kubernetes-dashboard
---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: kubernetes-dashboard
  namespace: argocd
spec:
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  destinations:
  - namespace: kubernetes-dashboard
    server: https://kubernetes.default.svc
  orphanedResources:
    warn: false
  sourceRepos:
  - '*'
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubernetes-dashboard
  namespace: argocd
spec:
  destination:
    server: https://kubernetes.default.svc
    namespace: kubernetes-dashboard
  project: kubernetes-dashboard
  source:
    repoURL: https://github.com/kubernetes/dashboard.git
    targetRevision: master
    path: charts/helm-chart/kubernetes-dashboard/
---
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
INNER_EOF
)
echo "$YAML" | kubectl apply -f -
EOF
)
ssh -debian@$EXTERNAL_IP "$COMMAND"
# droplet pipelinerun argocd sync + wait
COMMAND=$(cat <<-'EOF'
set -e
export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
# get argocd password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o json | jq -r '.data.password' | base64 -d)
# tekton pipeline + pipelinerun
YAML=$(cat <<INNER_EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-env-configmap
  namespace: tekton
data:
  ARGOCD_SERVER: argocd-server.argocd.svc:443
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-env-secret
  namespace: tekton
stringData:
  # choose one of username/password or auth token
  ARGOCD_USERNAME: admin
  ARGOCD_PASSWORD: $ARGOCD_PASSWORD
---
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: argocd-pipeline
  namespace: tekton
spec:
  tasks:
    - name: sync-application
      taskRef:
        name: argocd-task-sync-and-wait
      params:
        - name: argocd-version
          value: v2.6.7
        - name: application-name
          value: kubernetes-dashboard
---
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: argocd-pipelinerun
  namespace: tekton
spec:
  pipelineRef:
    name: argocd-pipeline
INNER_EOF
)
# cleanup any old?
kubectl delete --ignore-not-found=true -n tekton pipelinerun/argocd-pipelinerun
# apply new
echo "$YAML" | kubectl apply -f -
# wait for pipeline run
PIPELINERUN_NAME="argocd-pipelinerun"
while true
do
  status=$(kubectl get pipelinerun -n tekton $PIPELINERUN_NAME -o jsonpath='{.status.conditions[0].status}')
  if [ "$status" == "True" ]
  then
    echo "PipelineRun has completed successfully."
    break
  elif [ "$status" == "False" ]
  then
    echo "PipelineRun has failed."
    exit 1
  else
    echo "PipelineRun is still running."
    sleep 10
  fi
done
# get token to log in with
TOKEN=$(kubectl -n kubernetes-dashboard create token admin-user)
echo "TOKEN: $TOKEN"
EOF
)
ssh -t debian@$EXTERNAL_IP "$COMMAND"
# port forward
ssh -L 8443:127.0.0.1:8443 debian@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/kubernetes-dashboard -n kubernetes-dashboard 8443:443"'
