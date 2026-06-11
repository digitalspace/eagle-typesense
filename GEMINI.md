# Eagle Typesense Instructions

Search sync service for EPIC.

## Development Setup

- **Branch**: `main` (NOT develop)
- **Node Version**: 20+
- **Framework**: Node.js (CommonJS)

## CRITICAL Mandates

### Cross-Repo Coupling
- **Schemas**: `src/collections.js` is the source of truth for `QUERY_BY` and `FACET_BY`.
- **Sync**: `eagle-api` has inlined copies of these constants. Update BOTH repositories when schemas change.

### Operations
- **Full Sync**: `CronJob` runs nightly at 2 AM. Aborts if `listLookup.size < 50`.
- **Popularity Sync**: Runs nightly at 3 AM. Merges weighted click data from `penguin-analytics` into Typesense `popularity` field.
- **Change Stream**: `src/index.js` is an always-on deployment watching MongoDB for changes.

## Deployment & Secrets

- **Release Name**: `typesense`.
- **Required Secrets**: `typesense-api-key`, `eagle-api-mongodb`, `penguin-analytics-db`.
- **Probe Budget**: Typesense requires a long startup probe (20min+) for Raft log replay.
