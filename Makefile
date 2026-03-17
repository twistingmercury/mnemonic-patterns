.PHONY: help validate load

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nAvailable targets:\n"} /^[a-zA-Z0-9_-]+:.*##/ { printf "  %-12s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

validate: ## Validate all pattern files
	bash install/validate.sh

load: validate ## Load patterns into Mnemonic
	bash install/load.sh

test: ## Run BATS tests against the scripts
	bats tests/validate.bats tests/load.bats