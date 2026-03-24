#!/usr/bin/env bash
# ============================================================
# deploy.sh — Deploy the AWS Networking Lab CloudFormation stack
# Usage: ./scripts/deploy.sh [REGION] [STACK_NAME]
# ============================================================
set -euo pipefail

# ── Configuration ────────────────────────────────────────────
REGION="${1:-us-east-1}"
STACK_NAME="${2:-aws-networking-lab}"
TEMPLATE_FILE="cloudformation/vpc-stack.yaml"

echo "=========================================="
echo "  AWS Networking Lab — Stack Deployment"
echo "  Region:     $REGION"
echo "  Stack Name: $STACK_NAME"
echo "=========================================="

# ── Pre-flight: verify AWS CLI is configured ─────────────────
if ! aws sts get-caller-identity --region "$REGION" &>/dev/null; then
  echo "ERROR: AWS CLI not configured. Run 'aws configure' first."
  exit 1
fi

# ── Validate the template ─────────────────────────────────────
echo ""
echo "[1/3] Validating CloudFormation template..."
aws cloudformation validate-template \
  --template-body file://"$TEMPLATE_FILE" \
  --region "$REGION" \
  --output table

# ── Deploy the stack ──────────────────────────────────────────
echo ""
echo "[2/3] Deploying stack '$STACK_NAME'..."
aws cloudformation deploy \
  --template-file "$TEMPLATE_FILE" \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --parameter-overrides EnvironmentName="$STACK_NAME" \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset

# ── Print stack outputs ───────────────────────────────────────
echo ""
echo "[3/3] Stack outputs:"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs" \
  --output table

echo ""
echo "✅  Deployment complete!"
