#!/usr/bin/env bash
# NIGHTLY HABIT. Run before you close the laptop. Protects the budget.
set -uo pipefail
echo "==> Terraform teardown"
# Destroys every initialised Terraform directory under the CURRENT directory, without
# asking. Run it from the curriculum root only. A directory containing a file named
# .teardown-skip is left alone (the GCP lab VM uses this: it stops nightly instead).
while IFS= read -r -d '' d; do
  env="$(dirname "$d")"
  if [[ -e "$env/.teardown-skip" ]]; then
    echo "  skipping:   $env  (.teardown-skip)"
    continue
  fi
  echo "  destroying: $env"
  (cd "$env" && terraform destroy -auto-approve </dev/null) || echo "  FAILED: $env  <-- check manually"
done < <(find . -maxdepth 4 -type d -name '.terraform' -print0 2>/dev/null)

echo "==> kind clusters"
# Cluster names come from the pipe, so the y/N answer must be read from the terminal.
kind get clusters 2>/dev/null | while read -r c; do
  read -rp "  delete kind cluster '$c'? [y/N] " a </dev/tty
  [[ "$a" == "y" ]] && kind delete cluster --name "$c"
done

echo "==> Orphan check (things Terraform commonly misses)"
for r in $(aws configure get region 2>/dev/null || echo us-east-1); do
  echo "  region $r:"
  aws ec2 describe-instances --region "$r" \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
    --output text 2>/dev/null | sed 's/^/    EC2  /'
  aws ec2 describe-nat-gateways --region "$r" \
    --filter "Name=state,Values=available" \
    --query 'NatGateways[].NatGatewayId' --output text 2>/dev/null | tr '\t' '\n' | sed 's/^/    NAT  /'
  aws rds describe-db-instances --region "$r" \
    --query 'DBInstances[].DBInstanceIdentifier' --output text 2>/dev/null | tr '\t' '\n' | sed 's/^/    RDS  /'
  aws elbv2 describe-load-balancers --region "$r" \
    --query 'LoadBalancers[].LoadBalancerName' --output text 2>/dev/null | tr '\t' '\n' | sed 's/^/    ELB  /'
  aws eks list-clusters --region "$r" --query 'clusters' --output text 2>/dev/null | tr '\t' '\n' | sed 's/^/    EKS  /'
done
echo "==> Anything listed above is still billing. Kill it."
