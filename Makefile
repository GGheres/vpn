SHELL := /bin/bash

.PHONY: up down build logs prod-up prod-down prod-logs xray-sync xray-reload health issue gen-keys

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
