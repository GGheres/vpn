SHELL := /bin/bash

.PHONY: up down build logs prod-up prod-down prod-logs xray-sync xray-reload health issue gen-keys quickstart

up:
	docker compose --profile dev up --build

down:
	docker compose down

build:
	docker compose build --no-cache

logs:
	docker compose --profile dev logs -f

prod-up:
	docker compose -f docker-compose.prod.yml --profile prod up -d --build

prod-down:
	docker compose -f docker-compose.prod.yml --profile prod down

prod-logs:
	docker compose -f docker-compose.prod.yml --profile prod logs -f

xray-sync:
	bash scripts/api_sync.sh

xray-reload:
	bash scripts/xray_reload.sh

health:
	curl -fsS http://localhost:4000/health && echo

issue:
	bash scripts/issue_link.sh

gen-keys:
	bash scripts/generate_x25519.sh

# One-shot: bring up prod stack, wait for API, sync Xray, reload
quickstart:
	@echo "[1/4] Bringing up stack (prod profile)..."
	docker compose -f docker-compose.prod.yml --profile prod up -d --build
	@echo "[2/4] Waiting for API to be ready on http://localhost:4000/health ..."
	@bash -c 'for i in $$(seq 1 60); do \
	  if curl -fsS http://localhost:4000/health >/dev/null; then echo OK; exit 0; fi; \
	  sleep 1; \
	done; echo "API not ready after 60s" >&2; exit 1'
	@echo "[3/4] Ensuring default node exists ..."
	bash scripts/init_node.sh || true
	@echo "[4/5] Syncing Xray config with REALITY params from .env ..."
	bash scripts/api_sync.sh || true
	@echo "[5/5] Hot-reloading xray ..."
	bash scripts/xray_reload.sh || true
	@echo "Done. API at http://localhost:4000/health"
