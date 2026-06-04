#!/usr/bin/env bash
# Builds the dashboard's data.json by querying GitHub Actions via gh CLI.
#
# Output schema (consumed by dashboard.js):
#
#   {
#     "generatedAt": "2026-05-12T08:30:00Z",
#     "runs": [
#       {
#         "id": 123,
#         "name": "Backend CI",
#         "status": "completed",
#         "conclusion": "success",
#         "headBranch": "feature/test-environment",
#         "headSha": "abc1234...",
#         "displayTitle": "feat(test): wire test environments…",
#         "createdAt": "2026-05-12T08:25:00Z",
#         "updatedAt": "2026-05-12T08:27:00Z",
#         "durationSec": 120,
#         "url": "https://github.com/.../actions/runs/123"
#       },
#       ...
#     ]
#   }
#
# We pull the last 60 runs (across all branches and workflows) so the
# UI has enough data for a 30-run trend chart per workflow.

set -euo pipefail

REPO="${GITHUB_REPOSITORY:-reacti25/reacti}"
LIMIT="${RUN_LIMIT:-60}"

# `gh run list` returns newest-first. We ask for the fields the
# dashboard cares about, and compute durationSec ourselves below.
runs=$(gh run list \
  --repo "$REPO" \
  --limit "$LIMIT" \
  --json databaseId,name,status,conclusion,headBranch,headSha,displayTitle,createdAt,updatedAt,url)

# Re-shape: rename `databaseId` → `id`, add `durationSec` = updatedAt - createdAt.
shaped=$(echo "$runs" | jq '[.[] | {
  id: .databaseId,
  name,
  status,
  conclusion,
  headBranch,
  headSha,
  displayTitle,
  createdAt,
  updatedAt,
  url,
  durationSec: (
    (((.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)))
  )
}]')

# Top-level envelope with the generation timestamp.
jq -n \
  --arg generatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson runs "$shaped" \
  '{ generatedAt: $generatedAt, runs: $runs }'
