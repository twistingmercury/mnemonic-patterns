.PHONY: help up stop down

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nAvailable targets:\n"} /^[a-zA-Z0-9_-]+:.*##/ { printf "  %-12s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

up: ## Starts the mnemonic dev environment
	docker compose up

stop: ## Stops the mnemonic dev environment
	docker compose stop

down: ## Tears down the existing mnemonic dev environment
	docker compose down