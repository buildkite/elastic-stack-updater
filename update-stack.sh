#!/bin/bash
set -euxo pipefail

## -------------------------------------------------
## functions

stack_status() {
  aws cloudformation describe-stacks --stack-name "$1" --output text --query 'Stacks[].StackStatus'
}

stack_events() {
  aws cloudformation describe-stack-events --stack-name "$1" --output table --query 'sort_by(StackEvents, &Timestamp)[].[
    EventId,
    ResourceStatus
  ]' | sed 1,2d
}

stack_failures() {
  aws cloudformation describe-stack-events --stack-name "$1" --output table --query \
    "sort_by(StackEvents, &Timestamp)[?ResourceStatus=='CREATE_FAILED'].[LogicalResourceId,ResourceStatusReason]" \
  | sed 1,2d
}

## -------------------------------------------------
## main

stack_name="$1"

aws lambda invoke \
  --invocation-type RequestResponse \
  --function-name updateElasticStack \
  --region us-east-1 \
  --log-type Tail \
  --payload "{\"StackName\":\"$stack_name\"}" \
  output.json

jq '.LogResult' -f output.json | base64 --decode


# aws cloudformation wait change-set-create-complete \
#   --stack-name "$stack_name" \
#   --change-set-name "$change_set_name"
