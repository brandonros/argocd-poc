#!/bin/sh

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. $SCRIPT_DIR/tekton.sh

function get_argocd_password() {
  EXTERNAL_IP=$1
  COMMAND=$(cat <<EOF
    export KUBECONFIG="/home/debian/.kube/config"
    kubectl -n argocd get secret argocd-initial-admin-secret -o json | jq -r '.data.password' | base64 -d
EOF
)
  ARGOCD_PASSWORD=$(ssh -t debian@$EXTERNAL_IP "$COMMAND")
  echo "$ARGOCD_PASSWORD"
}

function sync_argocd_app() {
  EXTERNAL_IP=$1
  ARGOCD_APPLICATION_NAME=$2
  ARGOCD_PASSWORD=$3
  PIPELINE_YAML=$(cat $SCRIPT_DIR/../../yaml/templates/argocd-task-sync-and-wait-pipeline.yaml)
  PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s/{{ARGOCD_APPLICATION_NAME}}/$ARGOCD_APPLICATION_NAME/g")
  PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s/{{ARGOCD_PASSWORD}}/$ARGOCD_PASSWORD/g")
  tekton_run_pipeline "$EXTERNAL_IP" "argocd-sync-and-wait-pipeline-run" "$PIPELINE_YAML"
  get_tekton_pipeline_run_logs "$EXTERNAL_IP" "argocd-sync-and-wait-pipeline-run"
}
