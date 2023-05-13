#!/bin/sh

function kaniko_build_and_push() {
  EXTERNAL_IP=$1
  GIT_URL=$2
  IMAGE=$3
  DOCKERFILE=$4
  CONTEXT=$5
  PIPELINE_YAML=$(cat $SCRIPT_DIR/../yaml/pipelines/kaniko-build-and-push-pipeline.yaml)
  PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s/{{GIT_URL}}/$GIT_URL/g")
  PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s/{{IMAGE}}/$IMAGE/g")
  PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s/{{DOCKERFILE}}/$DOCKERFILE/g")
  PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s/{{CONTEXT}}/$CONTEXT/g")
  COMMAND=$(cat <<EOF
    set -e
    export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
    # cleanup any old?
    kubectl delete --ignore-not-found=true -n tekton pipelinerun/kaniko-build-and-push-pipelinerun
    # apply new
    echo "$PIPELINE_YAML" | kubectl apply -f -
    while true
    do
      status=\$(kubectl get pipelinerun -n tekton kaniko-build-and-push-pipelinerun -o jsonpath='{.status.conditions[0].status}')
      if [ "\$status" == "True" ]
      then
        echo "PipelineRun has completed successfully."
        break
      elif [ "\$status" == "False" ]
      then
        echo "PipelineRun has failed."
        exit 1
      else
        echo "PipelineRun is still running."
        sleep 10
      fi
    done
EOF
  )
  ssh debian@$EXTERNAL_IP "$COMMAND"
}
