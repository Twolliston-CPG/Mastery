# Run the CI checks locally with the exact tool versions CI pins.
#
#   make check            everything below
#   make scan             checkov + trivy, same flags and versions as security.yml iac-scan
#   make policy           the repository's own Conftest gate on its Terraform, as iac-scan runs it
#   make lint-workflows   actionlint + zizmor on .github/
#   make shellcheck       every tracked .sh, same severity as CI
#   make tools            (re)install the pinned binaries into .tools/bin
#
# Needs: curl, uv (https://docs.astral.sh/uv/). Python tools run through `uvx` at the pinned
# version, so the Homebrew checkov is never used: it ships without the graph policies and once
# reported a clean repository that CI then failed 13 checks on.
.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

TOOLS := .tools/bin
CHECKOV_VERSION := $(shell sed -n 's/^checkov==//p' .github/requirements/iac.in)
ZIZMOR_VERSION  := $(shell sed -n 's/^zizmor==//p' .github/requirements/actions.in)

.PHONY: help tools scan policy lint-workflows shellcheck check

help:  ## show this help
	@grep -E '^[a-z-]+:.*?##' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

tools:  ## install the pinned trivy, actionlint, shellcheck and conftest into .tools/bin
	@bash .github/scripts/tools.sh

scan: tools  ## checkov + trivy over the whole repository, as iac-scan runs them
	uvx --from "checkov==$(CHECKOV_VERSION)" checkov --config-file .checkov.yaml --directory .
	$(TOOLS)/trivy config --exit-code 1 --severity HIGH,CRITICAL --skip-version-check \
	  --ignorefile .trivyignore.yaml \
	  --skip-dirs curriculum/_reference --skip-dirs _figures --skip-dirs _backups .

policy: tools  ## the Conftest policy gate (infra/policy/terraform) on every tracked .tf in the real roots and Alpha
	$(TOOLS)/conftest verify --no-color --policy infra/policy/terraform --namespace terraform
	git ls-files -z -- 'infra/**/*.tf' 'curriculum/_setup/**/*.tf' 'curriculum/projects/alpha-cloud-foundation/**/*.tf' \
	  | xargs -0 $(TOOLS)/conftest test --no-color --parser hcl2 --policy infra/policy/terraform --namespace terraform

lint-workflows: tools  ## actionlint + zizmor + the no-deploy guard on .github/
	$(TOOLS)/actionlint -no-color -shellcheck $(TOOLS)/shellcheck .github/workflows/*.yml
	uvx --from "zizmor==$(ZIZMOR_VERSION)" zizmor --persona regular .github
	bash .github/scripts/no-deploy-from-actions.sh

shellcheck: tools  ## shellcheck -S warning on every tracked shell script
	git ls-files -z -- '*.sh' | xargs -0 $(TOOLS)/shellcheck -S warning

check: lint-workflows shellcheck scan policy  ## all of the above
