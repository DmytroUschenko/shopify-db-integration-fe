# Docker Debugging — Frontend

The frontend is a Remix/Express application. Two Docker setups exist:

| File | Purpose |
|---|---|
| `Dockerfile` | Production image (multi-stage, no dev tools) |
| `Dockerfile.debug` | Development image (all deps, Node.js inspector + `--watch`) |
| `docker-compose.yml` | Production Compose (used with `.env.prod`) |
| `docker-compose.debug.yml` | Debug Compose (used with `.env`, exposes debugger port, bind-mounts source) |

---

## Ports

| Port | Service |
|---|---|
| `3005` | Remix/Express HTTP server |
| `9229` | Node.js inspector (local dev only) |
| `5433` | PostgreSQL (host-mapped) |

---

## Recommended workflow — live reload + debugger

Open **two terminals**:

**Terminal 1 — start the local dev containers:**
```bash
make deploy-local
```

**Terminal 2 — watch for source changes and rebuild continuously:**
```bash
make watch        # alias for: npm run build:watch (remix watch)
```

**Terminal 3 (VS Code) — attach debugger:**
Press **F5** or open the Run panel and select **"Attach to Frontend (Docker)"**.

How it works:
1. Container starts → generates Prisma client → does an initial `remix build` → starts `node --watch --inspect server.js`
2. You edit source code on the host
3. `remix watch` (Terminal 2) detects the change and rebuilds `build/` on the host
4. Because the source directory is bind-mounted into the container (and `build/` is **not** isolated), the container's `node --watch` detects the updated build output and **automatically restarts the process** — no container restart needed

> **Why `node --watch`?** It is a Node.js 18+ built-in that watches all files loaded via `import`/`require`. When `server.js` imports from `build/`, any change there triggers a clean restart. No extra dependencies required.

---

## Attach a debugger

### VS Code

`.vscode/launch.json` is already committed. Just press **F5** or open the Run panel and select **"Attach to Frontend (Docker)"**.

If you need to recreate it manually:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Attach to Frontend (Docker)",
      "type": "node",
      "request": "attach",
      "port": 9229,
      "address": "localhost",
      "localRoot": "${workspaceFolder}",
      "remoteRoot": "/app",
      "sourceMaps": true,
      "restart": true,
      "skipFiles": ["<node_internals>/**", "**/node_modules/**"]
    }
  ]
}
```

`"restart": true` means VS Code automatically re-attaches after each `node --watch` restart — breakpoints stay active across rebuilds.

### Chrome DevTools

1. Open `chrome://inspect`
2. Click **Configure** → add `localhost:9229`
3. The Node process appears under **Remote Target**

---

## Useful commands

```bash
make local-logs        # tail logs from the local frontend container
make local-shell       # open a shell inside the running local container
make local-db-changes  # run Prisma migrations + regenerate client
make local-restart     # restart local containers (no rebuild)
make deploy-local FULL=1  # full reset: wipe, reinstall, rebuild, start
make local-clean       # stop local containers and remove volumes
make local-log-clean   # truncate Docker logs for local containers
make clean             # stop ALL containers and remove volumes
```

---

## Environment variables

Copy `.env.example` to `.env` and fill in values before starting:

```
SHOPIFY_API_KEY=
SHOPIFY_API_SECRET=
APP_URL=http://localhost:3005
BACKEND_URL=http://localhost:3001
BACKEND_API_KEY=
```

`DATABASE_URL` is constructed automatically from `POSTGRES_*` vars inside `docker-compose.debug.yml` and does not need to be set in `.env`.

---

## Testing webhooks locally

Shopify webhooks require a public HTTPS URL. Use ngrok or the Shopify CLI tunnel:

```bash
ngrok http 3005
```

Then set `NGROK_URL` and `APP_URL` in `.env` and run:

```bash
make deploy-local
```

---

## Teardown

```bash
make local-clean    # stop local containers, remove volumes
make clean          # stop ALL containers (prod + local) AND remove volumes
```
