#!/usr/bin/env bash
# ============================================================
# teardown.sh — Delete the AWS Networking Lab stack
# Usage: ./scripts/teardown.sh [REGION] [STACK_NAME]
# ============================================================
set -euo pipefail

REGION="${1:-us-east-1}"
STACK_NAME="${2:-aws-networking-lab}"

echo "================================================"
echo "  ⚠️  Tearing down stack: $STACK_NAME"
echo "  Region: $REGION"
echo "  This will DELETE all VPC resources!"
echo "================================================"
read -rp "  Confirm deletion? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "Deleting stack..."
aws cloudformation delete-stack \
  --stack-name "$STACK_NAME" \
  --region "$REGION"

echo "Waiting for deletion to complete..."
aws cloudformation wait stack-delete-complete \
  --stack-name "$STACK_NAME" \
  --region "$REGION"

echo ""
echo "✅  Stack '$STACK_NAME' deleted successfully."
