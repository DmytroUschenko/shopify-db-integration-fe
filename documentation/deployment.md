# Deployment Guide — Frontend

This document covers the full deployment flow for both **local development** and
**production**, explains what differs between them, and lists every parameter
that needs to be configured and where.

---

## Overview: local vs production

| | Local (`make deploy-local`) | Production (`make deploy-prod`) |
|---|---|---|
| **Where you run it** | Your machine | On the server (after SSH) |
| **How code gets there** | Already on disk | `git pull` |
| **App runtime** | `shopify app dev` (ngrok tunnel) | Docker Compose (all containers) |
| **Postgres** | Docker (postgres service only) | Docker (postgres service inside Compose) |
| **Shopify CLI command** | `shopify app dev` — starts dev tunnel | `shopify app deploy` — pushes config to Partners |
| **Toml config used** | `shopify.app.toml` | `shopify.app.prod.toml` |
| **Env file used** | `.env` | `.env.prod` |
| **Inspector / debugger** | Node.js inspector on `:9229` | Not exposed |
| **Prisma migrations** | Runs inside Docker container on start | Runs inside Docker container on start |

---

## Files involved

```
shopify-integration-frontend/
├── shopify.app.toml          ← local Shopify app config  (committed to git)
├── shopify.app.prod.toml     ← production Shopify app config  (committed to git)
├── .env.example              ← template — copy to .env or .env.prod
├── .env                      ← local secrets  (git-ignored)
├── .env.prod                 ← production secrets, lives on server only  (git-ignored)
├── docker-compose.yml        ← Compose file (used in prod with --env-file .env.prod)
└── Makefile                  ← deploy-local and deploy-prod targets
```

> `.env` and `.env.prod` are both covered by `.env*` in `.gitignore` —
> they are never committed. `shopify.app.prod.toml` contains no secrets and
> **is** committed to git.

---

## Parameters: what to set and where

### `shopify.app.toml` — local app config

Committed to git. Used by `shopify app dev` during local development.

| Field | What to set |
|---|---|
| `client_id` | Your app's Client ID from Shopify Partners dashboard. Same value as `SHOPIFY_API_KEY` in `.env`. |
| `application_url` | The ngrok tunnel URL. Update this after the first run. |
| `redirect_urls` | Match the tunnel URL pattern. Update after the first run. |
| `scopes` | OAuth scopes your app needs (e.g. `write_products,read_orders`). Must match `SCOPES` in `.env`. |
| `api_version` | Webhook API version (e.g. `2024-01`). Keep in sync with prod toml. |

### `shopify.app.prod.toml` — production app config

Committed to git. Used by `shopify app deploy` on the server.

| Field | What to set |
|---|---|
| `client_id` | Same Client ID as in `shopify.app.toml`. From Partners dashboard → your app → Client credentials. |
| `application_url` | Your real production domain, e.g. `https://app.yourdomain.com`. |
| `redirect_urls` | Your production callback URLs. Must exactly match what is registered in the Partners dashboard. |
| `scopes` | Same scopes as in the local toml. |
| `api_version` | Keep in sync with the local toml. |

### `.env` — local secrets

Copy from `.env.example`. Never committed. Used by `make deploy-local`.

```bash
cp .env.example .env
```

| Variable | Where to get it | Example |
|---|---|---|
| `SHOPIFY_API_KEY` | Partners dashboard → your app → Client credentials (Client ID) | `abc123def456` |
| `SHOPIFY_API_SECRET` | Partners dashboard → your app → Client credentials (Client secret) | `shpss_xxxx` |
| `APP_URL` | Your ngrok tunnel URL — update after the first run | `https://abc123.ngrok-free.app` |
| `SCOPES` | Same as `scopes` in `shopify.app.toml` | `write_products,read_orders` |
| `POSTGRES_USER` | Postgres username (default: `postgres`) | `postgres` |
| `POSTGRES_PASSWORD` | Postgres password (default: `postgres`) | `postgres` |
| `POSTGRES_DB` | Postgres database name (default: `shopify_frontend`) | `shopify_frontend` |
| `DATABASE_URL` | Points to local Docker postgres | `postgresql://postgres:postgres@localhost:5433/shopify_frontend` |
| `NGROK_URL` | Your ngrok tunnel URL (no trailing slash) | `https://abc123.ngrok-free.app` |
| `BACKEND_URL` | URL of the backend service | `http://localhost:3001` |
| `BACKEND_API_KEY` | Shared secret between frontend and backend | any random string |
| `SHOPIFY_CLI_PARTNERS_TOKEN` | Not needed locally — leave blank | |

### `.env.prod` — production secrets

Create this **on the server only**. Never committed. Used by `make deploy-prod`.

```bash
# On the server:
cp .env.example .env.prod
nano .env.prod
```

| Variable | Where to get it | Example |
|---|---|---|
| `SHOPIFY_API_KEY` | Same as local — Partners dashboard Client ID | `abc123def456` |
| `SHOPIFY_API_SECRET` | Same as local — Partners dashboard Client secret | `shpss_xxxx` |
| `APP_URL` | Your production domain (must match `application_url` in `shopify.app.prod.toml`) | `https://app.yourdomain.com` |
| `SCOPES` | Same as in `shopify.app.prod.toml` | `write_products,read_orders` |
| `POSTGRES_USER` | Postgres username | `postgres` |
| `POSTGRES_PASSWORD` | Strong password for production | `strongpassword` |
| `POSTGRES_DB` | Postgres database name | `shopify_frontend` |
| `DATABASE_URL` | Postgres connection string. If using the Compose internal postgres, use the internal hostname. | `postgresql://postgres:strongpassword@postgres:5432/shopify_frontend` |
| `BACKEND_URL` | URL of the production backend service | `https://api.yourdomain.com` |
| `BACKEND_API_KEY` | Shared secret — must match what the backend has | any strong random string |
| `SHOPIFY_CLI_PARTNERS_TOKEN` | **Required for prod.** Partners dashboard → Settings → Partner API clients → Create token | `prtapi_xxxx` |

---

## Local setup (first time)

### Prerequisites

- Node.js 20+
- Docker + Docker Compose
- Shopify Partners account + dev store
- Shopify CLI (`npm install -g @shopify/cli`)
- ngrok (`https://ngrok.com/download`)

### 1. Install dependencies

```bash
npm install
```

### 2. Create `.env`

```bash
cp .env.example .env
```

Fill in `SHOPIFY_API_KEY`, `SHOPIFY_API_SECRET`, and `NGROK_URL`.
Leave `APP_URL` as `http://localhost:3005` for now — update it after the first
tunnel is established.

### 3. Start ngrok

In a separate terminal:

```bash
ngrok http 3005
```

Copy the `https://` URL (e.g. `https://abc123.ngrok-free.app`) and set it as
`NGROK_URL` in `.env`.

### 4. Fill in `shopify.app.toml`

Add your `client_id` (same value as `SHOPIFY_API_KEY`).

### 5. Run the full local deploy

```bash
make deploy-local FULL=1
```

On first run Shopify CLI will open a browser to authenticate. Once done, copy
the tunnel URL into `APP_URL` in `.env` and into `application_url` /
`redirect_urls` in `shopify.app.toml`, then re-run.

### Subsequent daily starts

```bash
make deploy-local
```

This skips the wipe/reinstall and just starts postgres + the dev server.

---

## Production setup (first time on server)

### 1. Provision the server

Minimum: 1 vCPU, 1 GB RAM, Ubuntu 22.04 LTS.

### 2. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

### 3. Install nginx + certbot

```bash
sudo apt-get install -y nginx certbot python3-certbot-nginx
```

### 4. Clone and configure

```bash
git clone <your-repo-url> shopify-integration-frontend
cd shopify-integration-frontend
cp .env.example .env.prod
nano .env.prod   # fill in all values
```

Key env vars for production:
```
APP_URL=https://app.yourdomain.com
BACKEND_URL=https://api.yourdomain.com
POSTGRES_PASSWORD=<strong-random-password>
```

### 5. Fill in `shopify.app.prod.toml`

The file is already in the repo. Edit it:

```bash
nano shopify.app.prod.toml
```

- Set `client_id` to the Partners dashboard Client ID
- Replace `your-prod-domain.com` with your real domain
- Update all `redirect_urls` to match

### 6. Get the Partners API token (for `SHOPIFY_CLI_PARTNERS_TOKEN`)

1. Go to [partners.shopify.com](https://partners.shopify.com)
2. Settings → Partner API clients
3. Create a new API client with **Manage apps** scope
4. Copy the token into `.env.prod`

### 7. Start services

```bash
docker compose --env-file .env.prod up -d
```

### 8. Configure nginx

Create `/etc/nginx/sites-available/shopify-frontend`:

```nginx
server {
    server_name app.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/shopify-frontend /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 9. Obtain SSL certificate

```bash
sudo certbot --nginx -d app.yourdomain.com
```

### 10. Run the production deploy

```bash
make deploy-prod
```

---

## Deployment flows in detail

### `make deploy-local` (local)

```
docker compose --env-file .env up -d postgres
        ↓
source .env
NODE_OPTIONS="--inspect=0.0.0.0:9229" shopify app dev --config shopify.app.toml --tunnel-url "$NGROK_URL:3005"
```

`shopify app dev` does the following internally:
- Routes traffic through your ngrok tunnel and prints the public URL
- Registers the tunnel URL with your Shopify Partner app
- Starts the Remix dev server with HMR
- The Node.js inspector is available on `:9229` for VS Code / Chrome DevTools

Postgres runs in Docker; the app itself runs on the host via Shopify CLI.

### `make deploy-local FULL=1` (local — full reset)

```
docker compose --env-file .env down --remove-orphans
        ↓
rm -rf build/ node_modules/.cache
npm cache clean --force
        ↓
npm install
        ↓
[continues as make deploy-local above]
```

### `make deploy-prod` (server)

```
git pull
        ↓
docker compose --env-file .env.prod down --remove-orphans
        ↓
rm -rf build/ node_modules/.cache
npm cache clean --force
        ↓
npm install   (includes @shopify/cli from devDependencies)
        ↓
docker compose --env-file .env.prod up -d --build
  └─ Docker image is rebuilt from Dockerfile
  └─ On container start: ./node_modules/.bin/prisma migrate deploy && npm run start
        ↓
source .env.prod
shopify app deploy --config shopify.app.prod.toml --force
  └─ Pushes application_url, redirect_urls, scopes, webhook config
     to Shopify Partners dashboard (non-interactive via SHOPIFY_CLI_PARTNERS_TOKEN)
```

All services (app + postgres) run in Docker. The host is only used to run
`git pull`, `npm install`, and the Shopify CLI deploy step.

---

## Subsequent deployments

**Local** — normal daily start:
```bash
make deploy-local
```

**Local** — after changing dependencies or wanting a clean slate:
```bash
make deploy-local FULL=1
```

**Production** — after pushing new code to git:
```bash
ssh user@your-server.com
cd /opt/shopify-frontend
make deploy-prod
```

**Production** — updating (nginx/certbot already configured):
```bash
git pull
docker compose --env-file .env.prod up -d --build
docker compose exec frontend ./node_modules/.bin/prisma migrate deploy
```

---

## Environment files are git-ignored

The `.gitignore` contains `.env*` which covers both `.env` and `.env.prod`.
Neither file is ever committed.

`shopify.app.prod.toml` contains **no secrets** (only URLs, scopes, and the public
`client_id`) and **is** committed to git. This allows `make deploy-prod` to use it
on the server without any manual setup beyond the one-time steps above.

---

## Troubleshooting

**`shopify app deploy` hangs without output**
→ `SHOPIFY_CLI_PARTNERS_TOKEN` is missing or invalid in `.env.prod`.
Get a new token from Partners dashboard → Settings → Partner API clients.

**`NGROK_URL is not set` error**
→ Set `NGROK_URL` in `.env` before running `make deploy-local`.
Start ngrok (`ngrok http 3005`), copy the `https://` URL, and paste it in.

**`docker compose` uses wrong env values**
→ Make sure `.env.prod` (or `.env`) is present in the project root on the
server (or locally). The `--env-file` flag reads from that path.

**Prisma migration fails on container start**
→ Check that `DATABASE_URL` in `.env.prod` is reachable from inside the Docker
network. If using the Compose postgres service, the hostname must be `postgres`
(the service name), not `localhost`.

**`client_id` mismatch error from Shopify CLI**
→ The `client_id` in `shopify.app.prod.toml` must match the app registered in
your Partners dashboard. Confirm under Partners dashboard → Apps → your app →
Client credentials.

**Port 3005 already in use**
→ Stop any existing containers: `docker compose down` then re-run.
