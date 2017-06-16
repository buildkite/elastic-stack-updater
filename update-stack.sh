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

echo "+++ Querying vpc/subnets from ${stack_name}"

# There is a bizarre bug where AZ's can actually change over time. This means when the update
# happens and the results of Fn::GetAZs change you get strange errors along the lines of
#

vpc_id=vpc-53922135
subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query "Subnets[*].[SubnetId,AvailabilityZone]" --output text)
subnet_ids=$(awk '{print $1}' <<< "$subnets" | tr ' ' ',' | tr '\n' ',' | sed 's/,$//')
az_ids=$(awk '{print $2}' <<< "$subnets" | tr ' ' ',' | tr '\n' ',' | sed 's/,$//')

echo "$subnet_ids"
echo "$az_ids"

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
  "ParameterKey=VpcId,UsePreviousValue=true"
  )

echo "+++ Updating :cloudformation: ${stack_name}"
aws cloudformation update-stack \
  --stack-name "$stack_name" \
  --template-url "https://s3.amazonaws.com/buildkite-aws-stack/aws-stack.json" \
  --parameters "${params[@]}" \
  --capabilities CAPABILITY_NAMED_IAM

if ! aws cloudformation wait stack-update-complete --stack-name "$stack_name" ; then
  stack_events "$stack_name"
  stack_status "$stack_name"
  exit 1
fi

echo "Completed."

