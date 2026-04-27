# ============================================================
# shopify-integration-frontend — Makefile
# ============================================================
# Two workflows:
#   prod-*   — production containers (multi-stage build, no debugger)
#   local-*  — local dev containers (source mount, Node inspector on :9229)
# ============================================================

PROD_COMPOSE  = docker compose --env-file .env.prod
LOCAL_COMPOSE = docker compose -f docker-compose.debug.yml --env-file .env

.PHONY: help \
        build watch test \
        deploy-prod shopify-config-push prod-stop prod-start prod-restart prod-logs prod-shell prod-db-changes prod-clean \
        deploy-local local-stop local-start local-restart local-logs local-log-clean local-shell local-db-changes local-clean \
        clean

# ── Default ──────────────────────────────────────────────────
help:
	@echo ""
	@echo "shopify-integration-frontend"
	@echo "════════════════════════════════════════════════════════"
	@echo ""
	@echo "Host (no Docker):"
	@echo "  make build              Build Remix app"
	@echo "  make watch              Continuously rebuild Remix on source changes"
	@echo "  make test               Run Vitest unit tests"
	@echo ""
	@echo "Production (uses docker-compose.yml + .env.prod):"
	@echo "  make deploy-prod        git pull → rebuild containers → apply DB changes"
	@echo "  make shopify-config-push Push app config to Partners Dashboard (needs SHOPIFY_CLI_PARTNERS_TOKEN)"
	@echo "  make prod-stop          Stop prod containers (keep them)"
	@echo "  make prod-start         Start stopped prod containers"
	@echo "  make prod-restart       Restart prod containers (no rebuild)"
	@echo "  make prod-logs          Tail prod container logs"
	@echo "  make prod-shell         Shell into running prod frontend"
	@echo "  make prod-db-changes    Run Prisma migrations + regenerate client"
	@echo "  make prod-clean         Remove prod containers and volumes"
	@echo ""
	@echo "Local development (uses docker-compose.debug.yml + .env):"
	@echo "  make deploy-local            Start debug containers (inspector on :9229)"
	@echo "  make deploy-local FULL=1     Full reset: wipe, reinstall, rebuild, start"
	@echo "  make local-stop              Stop local containers (keep them)"
	@echo "  make local-start             Start stopped local containers"
	@echo "  make local-restart           Restart local containers (no rebuild)"
	@echo "  make local-logs              Tail local container logs"
	@echo "  make local-log-clean         Truncate Docker logs for local containers"
	@echo "  make local-shell             Shell into running local frontend"
	@echo "  make local-db-changes        Create new migrations if needed, apply them + regenerate client"
	@echo "  make local-clean             Remove local containers and volumes"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean              Remove ALL containers and volumes (prod + local)"
	@echo ""
	@echo "Debugging workflow:"
	@echo "  1. make deploy-local    → containers start with inspector on :9229"
	@echo "  2. Open VS Code → F5   → attaches debugger via .vscode/launch.json"
	@echo "  3. make watch           → (second terminal) live Remix rebuild on source changes"
	@echo ""

# ── Host-side (no Docker) ───────────────────────────────────
build:
	npm run build

watch:
	npm run build:watch

test:
	npm test

# ════════════════════════════════════════════════════════════
# PRODUCTION
# ════════════════════════════════════════════════════════════
# Run ON THE SERVER: ssh user@host, cd /project, make deploy-prod
# Uses docker-compose.yml + .env.prod
# Requires:
#   - .env.prod on server (not in git)
#   - client_id in shopify.app.prod.toml
#
# NOTE: App URL, scopes, and redirect URLs are managed directly
#   in the Shopify Partners Dashboard (no SHOPIFY_CLI_PARTNERS_TOKEN needed).
#   If you do have a Partners token and want to push config via CLI, run:
#     make shopify-config-push

deploy-prod:
	@echo "→ Pulling latest code..."
	git fetch origin main
	git reset --hard origin/main
	git clean -fd
	@echo "→ Stopping all prod containers..."
	$(PROD_COMPOSE) down --remove-orphans
	@echo "→ Cleaning build artifacts and npm cache..."
	rm -rf build/ node_modules/.cache
	npm cache clean --force
	@echo "→ Installing dependencies..."
	npm install
	@echo "→ Rebuilding and starting prod containers..."
	$(PROD_COMPOSE) up -d --build
	@echo "→ Production deployed"

# Optional: push app config (URLs, scopes) to Shopify Partners Dashboard via CLI.
# Requires SHOPIFY_CLI_PARTNERS_TOKEN in .env.prod.
shopify-config-push:
	set -a && . ./.env.prod && set +a && \
	  shopify app deploy --config shopify.app.prod.toml --allow-updates

prod-stop:
	$(PROD_COMPOSE) stop

prod-start:
	$(PROD_COMPOSE) start

prod-restart:
	$(PROD_COMPOSE) restart

prod-logs:
	$(PROD_COMPOSE) logs -f

prod-shell:
	$(PROD_COMPOSE) exec frontend sh

prod-db-changes:
	@echo "→ Running Prisma migrations..."
	$(PROD_COMPOSE) exec frontend ./node_modules/.bin/prisma migrate deploy
	@echo "→ Regenerating Prisma client..."
	$(PROD_COMPOSE) exec frontend ./node_modules/.bin/prisma generate
	@echo "→ DB changes applied"

prod-clean:
	$(PROD_COMPOSE) down -v --remove-orphans

# ════════════════════════════════════════════════════════════
# LOCAL DEVELOPMENT (with debugger)
# ════════════════════════════════════════════════════════════
# Uses docker-compose.debug.yml + .env
# Source is mounted into the container, Node inspector on :9229
# Attach VS Code debugger with F5 (.vscode/launch.json)

deploy-local:
	@if [ "$(FULL)" = "1" ]; then \
	  echo "→ Full reset: stopping containers..."; \
	  $(LOCAL_COMPOSE) down --remove-orphans; \
	  echo "→ Cleaning build artifacts and npm cache..."; \
	  rm -rf build/ node_modules/.cache; \
	  npm cache clean --force; \
	  echo "→ Installing dependencies..."; \
	  npm install; \
	  echo "→ Rebuilding and starting local containers..."; \
	  $(LOCAL_COMPOSE) up -d --build; \
	else \
	  echo "→ Starting local containers..."; \
	  $(LOCAL_COMPOSE) up -d; \
	fi
	@echo ""
	@echo "→ Local containers running (inspector on :9229)"
	@echo "→ Open VS Code → F5 to attach debugger"
	@echo "→ Run 'make watch' in another terminal for live Remix rebuild"

local-stop:
	$(LOCAL_COMPOSE) stop

local-start:
	$(LOCAL_COMPOSE) start

local-restart:
	$(LOCAL_COMPOSE) restart

local-logs:
	$(LOCAL_COMPOSE) logs -f

local-log-clean:
	@echo "→ Truncating Docker logs for local containers..."
	@for id in $$($(LOCAL_COMPOSE) ps -q); do \
	  log_file=$$(docker inspect --format='{{.LogPath}}' $$id); \
	  if [ -n "$$log_file" ]; then \
	    docker run --rm --privileged --pid=host alpine:latest \
	      nsenter -t 1 -m -- truncate -s 0 "$$log_file" \
	      && echo "  Cleared: $$log_file"; \
	  fi; \
	done
	@echo "→ Logs cleaned"

local-shell:
	$(LOCAL_COMPOSE) exec frontend sh

local-db-changes:
	@echo "→ Creating and applying Prisma migrations..."
	$(LOCAL_COMPOSE) exec frontend ./node_modules/.bin/prisma migrate dev
	@echo "→ Regenerating Prisma client..."
	$(LOCAL_COMPOSE) exec frontend ./node_modules/.bin/prisma generate
	@echo "→ DB changes applied"

local-clean:
	$(LOCAL_COMPOSE) down -v --remove-orphans

# ════════════════════════════════════════════════════════════
# CLEANUP (both)
# ════════════════════════════════════════════════════════════
clean:
	$(PROD_COMPOSE) down -v --remove-orphans 2>/dev/null || true
	$(LOCAL_COMPOSE) down -v --remove-orphans 2>/dev/null || true
	@echo "→ All containers and volumes removed"
