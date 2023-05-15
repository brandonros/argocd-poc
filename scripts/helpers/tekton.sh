#!/bin/sh

function tekton_run_pipeline() {
  EXTERNAL_IP=$1
  PIPELINERUN_NAME=$2
  PIPELINE_YAML=$3
  COMMAND=$(cat <<EOF
    set -e
    export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
    # cleanup any old?
    kubectl delete --ignore-not-found=true -n tekton pipelinerun/$PIPELINERUN_NAME
    # apply new
    echo "$PIPELINE_YAML" | kubectl apply -f -
    while true
    do
      status=\$(kubectl get pipelinerun -n tekton $PIPELINERUN_NAME -o jsonpath='{.status.conditions[0].status}')
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