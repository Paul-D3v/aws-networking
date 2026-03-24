#!/usr/bin/env bash
# ============================================================
# test-nat-gateway.sh — Verify outbound internet access from
# a private subnet instance via the NAT Gateway.
#
# Prerequisites:
#   1. A bastion EC2 instance running in the PUBLIC subnet.
#   2. A test EC2 instance running in the PRIVATE subnet.
#   3. Your SSH key pair (.pem file).
#
# Usage:
#   ./scripts/test-nat-gateway.sh \
#       <BASTION_PUBLIC_IP> \
#       <PRIVATE_INSTANCE_IP> \
#       <PATH_TO_KEY.pem>
# ============================================================
set -euo pipefail

BASTION_IP="${1:?Usage: $0 <BASTION_PUBLIC_IP> <PRIVATE_INSTANCE_IP> <KEY.pem>}"
PRIVATE_IP="${2:?Missing private instance IP}"
KEY_FILE="${3:?Missing key file path}"

echo "=============================================="
echo "  NAT Gateway Connectivity Test"
echo "  Bastion IP:  $BASTION_IP"
echo "  Private IP:  $PRIVATE_IP"
echo "  Key File:    $KEY_FILE"
echo "=============================================="

SSH_OPTS="-i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=10"

# ── Step 1: Verify bastion is reachable ───────────────────────
echo ""
echo "[1/4] Testing SSH to bastion host..."
ssh $SSH_OPTS ec2-user@"$BASTION_IP" "echo '  ✅ Bastion reachable'"

# ── Step 2: SSH to private instance via bastion (ProxyJump) ──
echo ""
echo "[2/4] Testing SSH to private instance through bastion..."
ssh $SSH_OPTS \
  -J ec2-user@"$BASTION_IP" \
  ec2-user@"$PRIVATE_IP" \
  "echo '  ✅ Private instance reachable via bastion'"

# ── Step 3: Test outbound internet (NAT GW) ───────────────────
echo ""
echo "[3/4] Testing outbound internet access from private instance..."
ssh $SSH_OPTS \
  -J ec2-user@"$BASTION_IP" \
  ec2-user@"$PRIVATE_IP" \
  "curl -s --max-time 10 https://checkip.amazonaws.com && echo '  ✅ Internet reachable via NAT Gateway'"

# ── Step 4: Confirm the egress IP is the NAT Gateway EIP ─────
echo ""
echo "[4/4] Checking egress IP (should match NAT Gateway EIP)..."
EGRESS_IP=$(ssh $SSH_OPTS \
  -J ec2-user@"$BASTION_IP" \
  ec2-user@"$PRIVATE_IP" \
  "curl -s --max-time 10 https://checkip.amazonaws.com")

echo "  Egress IP: $EGRESS_IP"
echo ""
echo "  → Compare this IP against the NAT Gateway Elastic IP in the AWS Console."
echo "    If they match, NAT Gateway is working correctly. ✅"
echo ""
echo "=============================================="
echo "  All tests passed!"
echo "=============================================="
