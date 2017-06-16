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

stack_follow() {
  until status=$(stack_status "$1"); [[ $status =~ (FAILED|COMPLETE) ]] ; do
    echo "Stack status is $status, continuing to poll"
    sleep 20
  done
  if [[ $status =~ FAILED ]] ; then
    stack_events "$1"
    echo -e "\033[33;31mStack update failed!\n$(stack_failures "$1")\033[0m"
    return 1
  else
    echo -e "\033[33;32mStack updated successfully\033[0m"
  fi
}

## -------------------------------------------------
## main

params=(
  "ParameterKey=AgentsPerInstance,UsePreviousValue=true"
  "ParameterKey=BuildkiteAgentRelease,UsePreviousValue=true"
  "ParameterKey=BuildkiteAgentToken,UsePreviousValue=true"
  "ParameterKey=BuildkiteApiAccessToken,UsePreviousValue=true"
  "ParameterKey=BuildkiteOrgSlug,UsePreviousValue=true"
  "ParameterKey=BuildkiteQueue,UsePreviousValue=true"
  "ParameterKey=ECRAccessPolicy,UsePreviousValue=true"
  "ParameterKey=InstanceType,UsePreviousValue=true"
  "ParameterKey=KeyName,UsePreviousValue=true"
  "ParameterKey=ManagedPolicyARN,UsePreviousValue=true"
  "ParameterKey=MaxSize,UsePreviousValue=true"
  "ParameterKey=MinSize,UsePreviousValue=true"
  "ParameterKey=RootVolumeSize,UsePreviousValue=true"
  "ParameterKey=ScaleDownAdjustment,UsePreviousValue=true"
  "ParameterKey=ScaleDownPeriod,UsePreviousValue=true"
  "ParameterKey=ScaleUpAdjustment,UsePreviousValue=true"
  "ParameterKey=SecretsBucket,UsePreviousValue=true"
  "ParameterKey=SpotPrice,UsePreviousValue=true"
  )

stack_name="$1"

set -x
aws cloudformation update-stack \
  --stack-name "$stack_name" \
  --template-url "https://s3.amazonaws.com/buildkite-aws-stack/aws-stack.json" \
  --parameters "${params[@]}" \
  --capabilities CAPABILITY_NAMED_IAM
