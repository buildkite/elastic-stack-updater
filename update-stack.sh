#!/bin/bash
set -euo pipefail

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

echo "--- :cloudformation: Waiting for any previous updates to complete"
aws cloudformation wait stack-update-complete \
  --stack-name "$stack_name"

echo "--- :lambda: Invoking updateElasticStack function"
output=$(aws lambda invoke \
  --invocation-type RequestResponse \
  --function-name updateElasticStack \
  --region us-east-1 \
  --log-type Tail \
  --payload "{\"StackName\":\"$stack_name\"}" \
  output.json)

[[ $? -eq 0 ]] || (
  echo $output
  exit 1
)

jq '.' < output.json

if [[ "$(jq --raw-output '.errorMessage' < output.json)" == "No updates are to be performed." ]] ; then
  echo "+++ No updates are needed! Stack is up-to-date"
  exit 0
fi

echo "--- :cloudformation: Waiting for stack update to complete"
aws cloudformation wait stack-update-complete \
  --stack-name "$stack_name"
