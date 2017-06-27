#!/bin/bash
set -euo pipefail

stack_name="$1"

echo "--- :cloudformation: Waiting for stack to complete"
aws cloudformation wait stack-update-complete \
  --stack-name "$stack_name"
