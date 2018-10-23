#!/bin/bash
set -euo pipefail


# download parfait binary
wget -N https://github.com/lox/parfait/releases/download/v1.1.3/parfait_linux_amd64
mv parfait_linux_amd64 parfait
chmod +x ./parfait

stack_name="$1"
stack_file="${STACK_FILE:-aws-stack.yml}"
stack_version="$(curl -Lfs "https://s3.amazonaws.com/buildkite-aws-stack/${stack_file}" \
  | grep -E '^Description: ' | sed 's/Buildkite stack //' | cut -d' ' -f2)"

echo "--- :lambda: Updating to ${stack_file} (${stack_version})"
output=$(aws lambda invoke \
  --invocation-type RequestResponse \
  --function-name updateElasticStack \
  --region us-east-1 \
  --log-type Tail \
  --payload "{\"StackName\":\"$stack_name\", \"StackFile\":\"${stack_file}\"}" \
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
