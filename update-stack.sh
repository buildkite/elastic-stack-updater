#!/bin/bash
set -euo pipefail


# download parfait binary
wget -N https://github.com/lox/parfait/releases/download/v1.0.0/parfait_linux_amd64
mv parfait_linux_amd64 parfait

stack_name="$1"
stack_version="$(curl -Lfs "https://s3.amazonaws.com/buildkite-aws-stack/${STACK_FILE:-aws-stack.json}" \
  | jq .Description -r | sed 's/Buildkite stack //')"

echo "--- :cloudformation: Waiting for any previous stack updates"
aws cloudformation wait stack-update-complete \
  --stack-name "$stack_name"

echo "--- :lambda: Updating to ${STACK_FILE:-aws-stack.json} (${stack_version})"
output=$(aws lambda invoke \
  --invocation-type RequestResponse \
  --function-name updateElasticStack \
  --region us-east-1 \
  --log-type Tail \
  --payload "{\"StackName\":\"$stack_name\", \"StackFile\":\"${STACK_FILE:-aws-stack.json}\"}" \
  output.json) || (
  echo "$output"
  exit 1
)

jq '.' < output.json

if [[ "$(jq --raw-output '.errorMessage' < output.json)" == "No updates are to be performed." ]] ; then
  echo "+++ No updates are needed! Stack is up-to-date"
  exit 0
fi

if [[ "$(jq --raw-output '.errorMessage' < output.json)" != "null" ]] ; then
  echo "^^^ +++"
  exit 1
fi

echo "--- :cloudformation: ⌛️ Waiting for update to complete"
./parfait watch-stack "$stack_name"
