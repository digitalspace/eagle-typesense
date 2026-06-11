# Eagle Typesense

Typesense search sync for EPIC. Keeps Typesense indexes synced with eagle-api's MongoDB.

## Quick Reference

| Setting | Value |
|---------|-------|
| Branch | `main` (NOT develop) |
| Package Manager | Yarn |
| Node Version | 20+ |
| Framework | Plain Node.js (no Express) |
| Database | Reads MongoDB (eagle-api), writes Typesense |

## Project Layout

```
src/
├── index.js               # MongoDB Change Stream listener (Deployment, always-on)
├── full-sync.js           # Zero-downtime full re-index (CronJob, nightly 2 AM)
├── popularity-sync.js     # Penguin-analytics → popularity scores (CronJob, nightly 3 AM)
├── collections.js         # SOURCE OF TRUTH for all schemas, QUERY_BY, FACET_BY
├── config.js              # buildMongoUri()
├── transform.js           # MongoDB → Typesense transforms
└── typesenseClient.js     # Typesense client singleton

helm/                      # Single chart (NOT helm/eagle-typesense/)
├── values.yaml            # All defaults
├── values-{dev,test,prod}.yaml
└── templates/             # typesense-deployment, sync-deployment, cronjobs, PVC, networkpolicy
```

## Collections (5 indexes)

| Collection | Source Model | default_sorting_field |
|------------|-------------|----------------------|
| `projects` | Project | `popularity` |
| `documents` | Document | `popularity` |
| `activities` | RecentActivity | `dateAdded` |
| `notifications` | ProjectNotification | `notificationReceivedDate` |
| `document_chunks` | DocumentChunk | _(none)_ |

## CRITICAL: Cross-Repo Coupling

`src/collections.js` = source of truth for `QUERY_BY`/`FACET_BY`.

**eagle-api's `api/helpers/typesenseClient.js` has INLINED COPIES** of these constants. Schema changes here → update eagle-api's `typesenseClient.js` too. Comment in eagle-api marks coupling.

## Architecture

### Change Stream (`src/index.js`)
- Watches MongoDB `epic` collection for insert/update/replace/delete
- Upserts transformed doc to Typesense on change
- Rebuilds `listLookup` on List/Organization doc changes
- Reconnects with exponential backoff on error

### Full Sync (`src/full-sync.js`)
1. Purge orphan collections (timestamped leftovers from failed runs)
2. Create new timestamped collection per schema
3. Stream all non-deleted docs from MongoDB, transform, batch-import
4. Swap alias atomically to new collection
5. Drop old collection

Safety: aborts if `listLookup.size < 50` (lookup degradation guard).

### Popularity Sync (`src/popularity-sync.js`)
1. Query penguin-analytics PostgreSQL for 30-day click events
2. Weighted scores: download=3, click=1
3. Batch-patch `popularity` field via `action: update`

## OpenShift Environments

| Env | Namespace | Typesense Internal |
|-----|-----------|-------------------|
| Dev | `6cdc9e-dev` | `eagle-typesense:8108` |
| Test | `6cdc9e-test` | `eagle-typesense:8108` |
| Prod | `6cdc9e-prod` | **NOT YET DEPLOYED** |

### Prod pre-deploy steps:
1. Create `typesense-api-key` secret in `6cdc9e-prod`
2. Verify `eagle-api-mongodb` secret exists
3. Optionally create `penguin-analytics-db` if enabling popularity

## Required OpenShift Secrets (per namespace)

| Secret | Keys | Purpose |
|--------|------|---------|
| `typesense-api-key` | `TYPESENSE_API_KEY`, `TYPESENSE_SEARCH_KEY` | Must exist before first deploy |
| `eagle-api-mongodb` | `MONGODB_USER`, `MONGODB_PASSWORD` | MongoDB read access |
| `penguin-analytics-db` | `PENGUIN_DB_*` | Only if `popularity.enabled: true` |

## Helm Notes

- Release name: `eagle-typesense` (pods: `eagle-typesense-*`; `fullnameOverride` in values.yaml)
- Feature toggles: `sync.enabled`, `reindex.enabled`, `popularity.enabled`, `contentExtract.enabled`
- Typesense startup probe: 120×10s = 20min budget — don't reduce without testing on largest env (Raft log replay on large datasets)
- Storage: `netapp-block-standard`, 10Gi PVC at `/data`

## Deployment

```bash
# Dev
helm upgrade --install eagle-typesense ./helm -f ./helm/values-dev.yaml -n 6cdc9e-dev

# Test/Prod via GitHub Actions
gh workflow run "Deploy to Test" --repo digitalspace/eagle-typesense -f version=dev
gh workflow run "Deploy to Prod" --repo digitalspace/eagle-typesense -f version=test
```

## Common Operations

```bash
# Force full re-index
oc create job ts-reindex-manual --from=cronjob/eagle-typesense-reindex -n 6cdc9e-{env}
oc logs -f job/ts-reindex-manual -n 6cdc9e-{env}

# Restart change stream listener
oc rollout restart deployment/eagle-typesense-sync -n 6cdc9e-{env}

# Port-forward for debugging
oc port-forward svc/eagle-typesense 8108:8108 -n 6cdc9e-{env}
```

## Code Style

Plain Node.js. CommonJS `require()`/`module.exports`. Async/await. Winston logging. No TypeScript, no bundler.

## MCP Tools

Context7 via MCPJungle (`192.168.5.22:8080`). `resolve-library-id` then `query-docs`.

## Conventions

- **Commits**: conventional commits. Never mention AI/Claude. Never `Co-Authored-By:` trailers.
- **Wiki**: [Typesense Search](https://github.com/bcgov/eagle-dev-guides/wiki/Typesense-Search).