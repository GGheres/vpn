# Systemd Units for VPN Stack

Two unit files are provided as examples. Adjust `WorkingDirectory` to the path
where your repo lives on the server (e.g., `/opt/vpn`).

- `deploy/systemd/vpn-dev.service`
- `deploy/systemd/vpn-prod.service`

## Install

```bash
# copy repo to server path, e.g.
sudo mkdir -p /opt/vpn
sudo rsync -a --delete ./ /opt/vpn/

# install units
sudo cp deploy/systemd/vpn-dev.service /etc/systemd/system/
sudo cp deploy/systemd/vpn-prod.service /etc/systemd/system/

# reload and enable
sudo systemctl daemon-reload
sudo systemctl enable vpn-dev.service
sudo systemctl enable vpn-prod.service

# start one of them
sudo systemctl start vpn-dev.service
# or
sudo systemctl start vpn-prod.service

# logs
journalctl -u vpn-dev.service -f
journalctl -u vpn-prod.service -f
```

Notes:
- Dev unit runs `docker compose up -d --build` with `COMPOSE_PROFILES=dev`.
- Prod unit runs `docker compose -f docker-compose.prod.yml up -d --build` with `COMPOSE_PROFILES=prod`.
- Ensure Docker is installed and `docker compose` is available at `/usr/bin/docker` or update ExecStart paths accordingly.
