# ProjDesk API (Cloudflare Workers)

Backend for ProjDesk — stores models, version history, and share links.

## Stack

- **Runtime**: Cloudflare Workers
- **Database**: Cloudflare D1 (SQLite)
- **Language**: TypeScript

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/health` | Health check |
| `POST` | `/api/workspaces` | Create workspace |
| `GET` | `/api/workspaces/:id` | Get workspace with models |
| `POST` | `/api/workspaces/:id/models` | Create model |
| `GET` | `/api/models/:id` | Get model |
| `PUT` | `/api/models/:id` | Update model (auto-versions) |
| `DELETE` | `/api/models/:id` | Delete model |
| `GET` | `/api/models/:id/versions` | List version history |
| `GET` | `/api/versions/:id` | Get specific version |
| `POST` | `/api/share` | Create share link |
| `GET` | `/api/share/:code` | Get shared data |

## Local Development

```bash
cd backend
npm install
npm run db:init     # Initialize local D1 database
npm run dev         # Start local dev server
```

## Deploy

```bash
# Create D1 database (first time only)
wrangler d1 create projdesk-db
# Copy database_id to wrangler.toml

# Initialize production database
npm run db:prod

# Deploy
npm run deploy
```

## Data Model

```
workspaces (id, name, created_at, updated_at)
  └── models (id, workspace_id, name, doc, fields_json, ...)
        └── model_versions (id, model_id, fields_json, label, ...)
share_links (code, workspace_id, data_json, ...)
```

Model fields are stored as JSON strings (the same format as ProjDesk's ABI).
