#!/bin/bash
set -euo pipefail

stack_name="$1"
stack_version="$(curl -Lfs "https://s3.amazonaws.com/buildkite-aws-stack/${STACK_FILE:-aws-stack.json}" \
  | jq .Description -r | sed 's/Buildkite stack //')"

echo "+++ :lambda: Triggering lambda function updateElasticStack"
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

buildkite-agent pipeline upload << EOF
steps:
  - wait
  - name: "⌛️ Wait for ${stack_version}"
    agents:
      queue: "${BUILDKITE_AGENT_META_DATA_QUEUE}"
      buildkite-aws-stack: "${stack_version}"
    command: ./wait-stack.sh "${stack_name}"
EOF
