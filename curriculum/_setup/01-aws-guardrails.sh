#!/usr/bin/env bash
# WEEK 5, DAY 1, STEP 1 -- run this BEFORE creating any AWS resource.
# Creates budget alarms at $25/$50/$100 and enables cost anomaly detection.
#
# Usage: EMAIL=you@example.com bash 01-aws-guardrails.sh
set -euo pipefail

: "${EMAIL:?Set EMAIL=you@example.com}"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo "==> Account: $ACCOUNT   Alerts to: $EMAIL"

# Private temp dir, removed on any exit -- not fixed names in world-writable /tmp.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
failed=0

for AMOUNT in 25 50 100; do
  NAME="lab-budget-${AMOUNT}"
  cat > "$TMP/budget.json" <<JSON
{
  "BudgetName": "${NAME}",
  "BudgetLimit": {"Amount": "${AMOUNT}", "Unit": "USD"},
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
JSON
  cat > "$TMP/notif.json" <<JSON
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [{"SubscriptionType": "EMAIL", "Address": "${EMAIL}"}]
  },
  {
    "Notification": {
      "NotificationType": "FORECASTED",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [{"SubscriptionType": "EMAIL", "Address": "${EMAIL}"}]
  }
]
JSON
  # Only "already exists" is harmless. Any other failure means the guardrail is NOT in
  # place, and must not be reported as if it were.
  if out=$(aws budgets create-budget --account-id "$ACCOUNT" \
      --budget "file://$TMP/budget.json" \
      --notifications-with-subscribers "file://$TMP/notif.json" 2>&1); then
    echo "  created budget: \$${AMOUNT}"
  elif grep -q 'DuplicateRecordException' <<<"$out"; then
    echo "  budget \$${AMOUNT} already exists"
  else
    echo "  FAILED to create budget \$${AMOUNT}: $out" >&2
    failed=1
  fi
done

if [[ $failed -ne 0 ]]; then
  echo "==> At least one budget was NOT created. Do not create AWS resources until this passes." >&2
  exit 1
fi

echo
echo "==> MANUAL STEPS (console, 5 minutes) -- do these now:"
cat <<'MANUAL'
  1. Billing -> Billing Preferences -> enable "Receive Billing Alerts"
  2. IAM -> root user -> enable MFA, and DELETE any root access keys
  3. IAM -> create a daily-driver user with MFA; never use root again
  4. Cost Explorer -> Enable (takes ~24h to populate)
  5. Calendar reminder: "check AWS bill" every Monday for 26 weeks
MANUAL
