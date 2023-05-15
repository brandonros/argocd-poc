#!/bin/sh

function kaniko_build_and_push() {
  EXTERNAL_IP=$1
  GIT_URL=$2
  IMAGE=$3
  DOCKERFILE=$4
  CONTEXT=$5
  PIPELINE_YAML=$(cat $SCRIPT_DIR/../../yaml/pipelines/kaniko-build-and-push-pipeline.yaml)
  PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s#{{GIT_URL}}#$GIT_URL#g")
  PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s#{{IMAGE}}#$IMAGE#g")
  PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s#{{DOCKERFILE}}#$DOCKERFILE#g")
  PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s#{{CONTEXT}}#$CONTEXT#g")
  tekton_run_pipeline "$EXTERNAL_IP" "kaniko-build-and-push-pipelinerun" "$PIPELINE_YAML"
}
