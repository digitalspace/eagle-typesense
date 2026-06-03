# eagle-typesense

Typesense search engine and MongoDB sync service for the EPIC platform.

## Architecture

```
eagle-public/admin ──HTTP──▶ eagle-api (typesenseProxy.js)
                                  │ injects allowed_roles filter
                                  ▼
                             Typesense server ◀── typesense-sync (this repo)
                                                        │
                                                  MongoDB (epic collection)
                                                  MinIO (PDF extraction)
                                                  PostgreSQL (popularity scores)
```

## Components

| Component | Description |
|-----------|-------------|
| **Typesense server** | Full-text search engine (deployed via Helm) |
| **Change Stream listener** | Real-time sync from MongoDB → Typesense (`src/index.js`) |
| **Full sync CronJob** | Nightly zero-downtime re-index (`src/full-sync.js`) |
| **Popularity sync** | Nightly score update from penguin-analytics (`src/popularity-sync.js`) |
| **Content extraction** | PDF text extraction + chunking (`src/content-extract.js`) |

## Collections

| Collection | Source Schema | Purpose |
|------------|--------------|---------|
| `documents` | Document | Project documents (PDFs, reports) |
| `projects` | Project | EA projects |
| `activities` | RecentActivity | News/updates feed |
| `notifications` | ProjectNotification | Project notifications |
| `document_chunks` | DocumentChunk | Full-text search within PDFs |

## Quick Start

```bash
# Install dependencies
npm install

# Copy environment config
cp .env.example .env

# Start Change Stream listener (real-time sync)
npm start

# Run full re-index
npm run full-sync

# Run popularity score update
npm run popularity-sync
```

## Environment Variables

See [`.env.example`](.env.example) for all configuration options.

### Required

| Variable | Description |
|----------|-------------|
| `TYPESENSE_HOST` | Typesense server hostname |
| `TYPESENSE_PORT` | Typesense server port (default: 8108) |
| `TYPESENSE_API_KEY` | Admin API key |
| `MONGODB_HOST` | MongoDB hostname |
| `MONGODB_DATABASE` | Database name (default: epic) |

### Optional

| Variable | Description |
|----------|-------------|
| `MONGODB_USERNAME` | MongoDB auth username |
| `MONGODB_PASSWORD` | MongoDB auth password |
| `MONGODB_DIRECT` | Use directConnection (for port-forwarding) |
| `MINIO_HOST` | Object store for PDF extraction |
| `PENGUIN_DB_HOST` | PostgreSQL for popularity scores |

## Deployment

Deployed to OpenShift via Helm chart in `helm/`.

```bash
# Deploy to dev
helm upgrade --install typesense ./helm \
  --namespace 6cdc9e-dev \
  --values ./helm/values-dev.yaml

# Deploy to test/prod
helm upgrade --install typesense ./helm \
  --namespace 6cdc9e-{test,prod} \
  --values ./helm/values-{test,prod}.yaml
```

## Access Control

All documents get an `allowed_roles` field populated from MongoDB's `read` array.
Typesense scoped search keys embed a `filter_by: "allowed_roles:=[<roles>]"` constraint
so clients physically cannot bypass access control. Fail-closed: documents without a
`read` array default to `['sysadmin']` visibility only.
