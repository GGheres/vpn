
# API Endpoints (MVP)

- GET  /health
- POST /v1/users
- POST /v1/issue
- POST /v1/nodes/:id/sync
- POST /v1/nodes/:id/reload

# Nodes CRUD

- GET    /v1/nodes
- POST   /v1/nodes
- GET    /v1/nodes/:id
- PATCH  /v1/nodes/:id
- DELETE /v1/nodes/:id

Notes:
- Request/response JSON. Private key is stored in DB but never returned in responses.
- Sync accepts overrides in body (e.g., {"privateKey": "..."}).

All responses JSON with structured logging.
