# First Deploy — VPS + Nginx

This guide covers the one-time server setup and first production deployment using `make deploy-prod`.

`make deploy-prod` does everything automatically: `git pull` → rebuild Docker containers → start services → `shopify app deploy`. You only need to set up the server once.

---

## Prerequisites

- VPS running Ubuntu 22.04+
- A domain pointed at your VPS IP (e.g. `app.yourdomain.com`)
- Shopify Partner app created in the Partners dashboard
- Repo access from the VPS (SSH key or HTTPS token)

---

## Step 1 — Install Dependencies on VPS (once)

```bash
# Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker

# Docker Compose plugin
sudo apt install -y docker-compose-plugin

# Shopify CLI (needed for `shopify app deploy` inside make deploy-prod)
npm install -g @shopify/cli

# Nginx + Certbot
sudo apt install -y nginx certbot python3-certbot-nginx
```

---

## Step 2 — Clone the Repo on VPS (once)

```bash
cd /var/www
git clone <your-repo-url> shopify-frontend
cd shopify-frontend/shopify-integration-frontend
```

---

## Step 3 — Create `.env.prod` on VPS (once, not in git)

```bash
nano /var/www/shopify-frontend/shopify-integration-frontend/.env.prod
```

```env
SHOPIFY_API_KEY=your_client_id
SHOPIFY_API_SECRET=your_api_secret
APP_URL=https://app.yourdomain.com
SCOPES=write_products,read_orders,read_customers
BACKEND_URL=https://api.yourdomain.com
BACKEND_API_KEY=your_shared_secret

POSTGRES_USER=postgres
POSTGRES_PASSWORD=a_strong_password
POSTGRES_DB=shopify_frontend

# Required for non-interactive `shopify app deploy` in CI/CD
SHOPIFY_CLI_PARTNERS_TOKEN=your_partners_token
```

> Get `SHOPIFY_CLI_PARTNERS_TOKEN` from: Shopify Partners dashboard -> Settings -> Partner API clients.

---

## Step 4 — Fill in `shopify.app.prod.toml` (once)

Edit `shopify.app.prod.toml` in the repo with your real domain and client ID:

```toml
name = "shopify-integration-frontend"
client_id = "your_client_id_here"   # Partners dashboard -> Apps -> your app -> Client credentials

application_url = "https://app.yourdomain.com"
embedded = true

[access_scopes]
scopes = "write_products,read_orders,read_customers"

[auth]
redirect_urls = [
  "https://app.yourdomain.com/auth/callback",
  "https://app.yourdomain.com/auth/shopify/callback",
  "https://app.yourdomain.com/shopify/auth/callback",
]

[webhooks]
api_version = "2024-01"

[pos]
embedded = false
```

Commit and push this file — it contains no secrets.

---

## Step 5 — Nginx Config (once)

```bash
sudo nano /etc/nginx/sites-available/shopify-frontend
```

```nginx
server {
    listen 80;
    server_name app.yourdomain.com;

    location / {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/shopify-frontend /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

---

## Step 6 — SSL Certificate (once, required by Shopify)

Shopify requires HTTPS for all app and redirect URLs.

```bash
sudo certbot --nginx -d app.yourdomain.com
```

Certbot auto-renews. Verify with:

```bash
sudo certbot renew --dry-run
```

---

## Step 7 — First Deploy

```bash
cd /var/www/shopify-frontend/shopify-integration-frontend
make deploy-prod
```

This runs the following in order:

1. `git pull` — fetch latest code
2. `docker compose down` — stop existing containers
3. `npm install` — install deps on host (for Shopify CLI)
4. `docker compose up -d --build` — build the multi-stage Docker image, start `frontend` + `postgres` containers
5. `shopify app deploy --config shopify.app.prod.toml` — push app config to the Partners dashboard

The app container binds port `3005` on the host. Nginx proxies `443` -> `localhost:3005`. Docker manages the app process — no PM2 needed.

---

## Every Future Deploy

```bash
# SSH into the VPS, then:
cd /var/www/shopify-frontend/shopify-integration-frontend
make deploy-prod
```

One command handles everything.

---

## Useful Commands

| Command | Description |
|---|---|
| `make prod-logs` | Tail container logs |
| `make prod-shell` | Shell into the running app container |
| `make prod-restart` | Restart containers without rebuilding |
| `make prod-db-changes` | Run Prisma migrations after schema changes |
| `make prod-stop` | Stop containers (keep them) |
| `make prod-start` | Start stopped containers |
| `make prod-clean` | Remove containers and volumes |
