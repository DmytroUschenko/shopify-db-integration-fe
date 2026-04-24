---
description: "Use when working with Prisma schema, migrations, or database commands. Ensures all Prisma operations run from the appropriate container to maintain database consistency and avoid connection issues."
applyTo: "prisma/**,**/*.prisma"
---

# Prisma Container Execution Rule

All Prisma commands **MUST** run from within the appropriate Docker container. Do NOT run Prisma commands directly on the host machine.

## Container Commands

### Running Migrations + Regenerate Client
```bash
make local-db-changes   # local dev containers
make prod-db-changes    # production containers
# Equivalent to: ./node_modules/.bin/prisma migrate deploy && ./node_modules/.bin/prisma generate
```

### Opening Prisma Studio
```bash
# Prisma Studio can be run locally and will connect to the database:
npx prisma studio
```

### For Other Prisma Commands
Use the frontend container:
```bash
# Local development:
make local-shell  # then run ./node_modules/.bin/prisma <command> inside the shell

# Production:
make prod-shell   # then run ./node_modules/.bin/prisma <command> inside the shell
```

Examples:
- `./node_modules/.bin/prisma migrate dev` — Create and apply a new migration (preferred for local development)
- `./node_modules/.bin/prisma db seed` — Run seeding scripts
- `./node_modules/.bin/prisma generate` — Generate Prisma Client
- `./node_modules/.bin/prisma validate` — Validate schema

**Note**: Prefer creating migrations over `db push`. Migrations are version-controlled, trackable, and safer for team environments.

## Why?
- Database connection strings are configured in the container environment
- The database service is only accessible from within the Docker network
- Running Prisma locally can cause connection timeouts or schema sync errors

## Migration-First Approach

**Always create migrations** for schema changes. This ensures:
- Changes are version-controlled and tracked in `prisma/migrations/`
- Team members have a clear history of what changed and when
- Deployments are reproducible and rollback-friendly

```bash
# ✅ Correct: Create a migration (inside container shell)
make local-shell
./node_modules/.bin/prisma migrate dev --name add_user_email

# ❌ Wrong: Push schema directly without migration
./node_modules/.bin/prisma db push
```

## Never Do This
- `npx prisma migrate deploy` (on host)
- `npx prisma db push` (on host, or without creating a migration)
- `npx prisma generate` (outside container without proper env vars)

## Before Suggesting Changes
When suggesting edits to `prisma/schema.prisma` or Prisma operations, always remind users to run the commands through the container using the methods above.
