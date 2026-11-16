# dx.client: the same commands as every DX repo (`make help`).
# `make setup` once, then `make dev` runs the app on this machine. To run the
# whole DX stack, in Docker or not, use infra.dx.

IMAGE ?= dx-client:local
RAWGRAPHS_DIR := ../rawgraphs-charts
# yarn link with a folder of this repo's own, so it doesn't re-point a link
# other checkouts on this machine rely on.
LINKS := $(CURDIR)/node_modules/.links

.DEFAULT_GOAL := help
.PHONY: help setup charts dev build lint test node-version

help: ## List the commands
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-10s %s\n", $$1, $$2}'

setup: node-version ## Install dependencies, link ../rawgraphs-charts, create .env
	yarn install
	@$(MAKE) --no-print-directory charts
	@[ -f .env ] || { cp .env.example .env && echo "Created .env from .env.example"; }

charts: ## Rebuild ../rawgraphs-charts and link it in (after changing the charts)
	@[ -d $(RAWGRAPHS_DIR) ] || { echo "Clone rawgraphs-charts next to this repo first (make repos in infra.dx)." >&2; exit 1; }
	cd $(RAWGRAPHS_DIR) && yarn install && npx rollup -c
	rm -rf "$(LINKS)/@rawgraphs/rawgraphs-charts"
	cd $(RAWGRAPHS_DIR) && yarn link --link-folder "$(LINKS)"
	yarn link @rawgraphs/rawgraphs-charts --link-folder "$(LINKS)"

dev: ## Run the app on http://localhost:3000, reloading on changes
	@[ -f .env ] || { echo "No .env yet: run make setup." >&2; exit 1; }
	yarn dev

build: ## Build the Docker image, as CI does
	docker build -t $(IMAGE) .

lint: ## Check code style, as CI does
	yarn prettier src/app --check

test: ## Run the Cypress tests (the app must be running)
	npx cypress run

node-version:
	@want="$$(cut -d. -f1 .nvmrc)"; have="$$(node --version 2>/dev/null | sed 's/^v//; s/\..*//')"; \
	[ "$$want" = "$$have" ] || echo "Note: this repo uses Node $$(cat .nvmrc) (.nvmrc) and you have $$(node --version 2>/dev/null || echo none). Run: nvm use"
