#!/bin/sh

function tekton_run_pipeline() {
  EXTERNAL_IP=$1
  PIPELINE_RUN_NAME=$2
  PIPELINE_YAML=$3
  ENCODED_PIPELINE_YAML=$(echo "$PIPELINE_YAML" | base64) # encode to workaround weird edge cases about passing $ | ' " in this weird nested string pipe to SSH context
  COMMAND=$(cat <<EOF
    set -e
    export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
    # cleanup any old?
    kubectl delete --ignore-not-found=true -n tekton pipelinerun/$PIPELINE_RUN_NAME
    # apply new
    echo "$ENCODED_PIPELINE_YAML" | base64 --decode | kubectl apply -f -
    while true
    do
      status=\$(kubectl get pipelinerun -n tekton $PIPELINE_RUN_NAME -o jsonpath='{.status.conditions[0].status}')
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

function get_tekton_pipeline_run_logs() {
  EXTERNAL_IP=$1
  PIPELINE_RUN_NAME=$2
  COMMAND=$(cat <<EOF
    export KUBECONFIG="/home/debian/.kube/config"
    kubectl -n tekton get pipelinerun "$PIPELINE_RUN_NAME" -o json | jq -r '.status.childReferences[].name' | while read TASK_RUN_NAME
    do
      POD_NAME=\$(kubectl -n tekton get taskrun "\$TASK_RUN_NAME" -o jsonpath='{.status.podName}')
      kubectl logs -n tekton "\$POD_NAME"
    done
EOF
)
  ssh debian@$EXTERNAL_IP "$COMMAND"
}
