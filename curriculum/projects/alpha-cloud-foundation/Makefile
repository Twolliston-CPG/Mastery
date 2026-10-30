.DEFAULT_GOAL := help
ENV ?= dev
TF  := terraform -chdir=environments/$(ENV)

.PHONY: help bootstrap init plan apply destroy fmt validate lint scan policy verify cost clean

help:  ## show this help
	@grep -E '^[a-z-]+:.*?##' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

bootstrap:  ## create the state bucket (run ONCE, before anything else)
	cd bootstrap && terraform init && terraform apply
	@echo ""
	@echo ">>> Copy the bucket name into environments/*/backend.tf, then: make init"

init:  ## terraform init for $(ENV)
	$(TF) init

plan:  ## terraform plan for $(ENV)
	$(TF) plan -out=tf.plan

apply:  ## terraform apply for $(ENV)
	$(TF) apply

destroy:  ## DESTROY $(ENV) -- leaves nothing billable
	$(TF) destroy

fmt:  ## format all terraform
	terraform fmt -recursive

validate:  ## validate every module and environment
	@for d in modules/*/ environments/*/ bootstrap/; do \
		echo "--> $$d"; \
		terraform -chdir="$$d" init -backend=false >/dev/null && \
		terraform -chdir="$$d" validate || exit 1; \
	done

lint:  ## tflint across the repo
	tflint --init && tflint --recursive --format compact

scan:  ## checkov security scan
	checkov -d . --framework terraform --quiet \
		--skip-check CKV_AWS_18,CKV_AWS_144

policy:  ## the policy gate: test the policies, then run them against $(ENV)'s plan
	conftest verify --policy policies/conftest
	$(TF) show -json tf.plan > environments/$(ENV)/plan.json
	conftest test --policy policies/conftest environments/$(ENV)/plan.json

verify:  ## prove the acceptance criteria for $(ENV)
	@echo "--- no static AWS credentials anywhere ---"
	@! git grep -InE 'AKIA[0-9A-Z]{16}' -- . && echo "  OK: no access key IDs"
	@! git grep -InE 'aws_secret_access_key' -- . && echo "  OK: no secret keys"
	@echo "\n--- state is remote and encrypted ---"
	@grep -q 'backend "s3"' environments/$(ENV)/backend.tf && echo "  OK: s3 backend"
	@grep -q 'encrypt      = true' environments/$(ENV)/backend.tf && echo "  OK: encrypted"
	@grep -q 'use_lockfile' environments/$(ENV)/backend.tf && echo "  OK: locking enabled"
	@echo "\n--- the app answers ---"
	@curl -sfo /dev/null -w "  HTTP %{http_code} in %{time_total}s\n" \
		"$$($(TF) output -raw url)" || echo "  not deployed"
	@echo "\n--- alarms exist (force one to test the notification path) ---"
	@$(TF) output -json alarm_names | jq -r '.[]' | sed 's/^/  /'

cost:  ## last 7 days of spend by service
	@aws ce get-cost-and-usage \
		--time-period Start=$$(date -u -v-7d +%F 2>/dev/null || date -u -d '7 days ago' +%F),End=$$(date -u +%F) \
		--granularity DAILY --metrics UnblendedCost \
		--group-by Type=DIMENSION,Key=SERVICE \
		--query 'ResultsByTime[-1].Groups[?Metrics.UnblendedCost.Amount!=`0`].[Keys[0],Metrics.UnblendedCost.Amount]' \
		--output table

clean:  ## remove local terraform caches
	find . -type d -name .terraform -prune -exec rm -rf {} +
	find . -name 'tf.plan' -delete
