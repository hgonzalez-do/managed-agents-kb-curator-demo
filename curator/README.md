# curator/ — what the Managed Agent runs

These scripts are the deterministic core of the curator. The agent clones this repo
(read-only) next to the app repo and runs them from inside the app repo; the runbook in
`agent/prompts/curator.md` says when. Operators use the same scripts for setup and demo staging.

| File | Used by | What it does |
|---|---|---|
| `releases.py` | agent, operator | `fetch` new doctl releases as JSON; `index` regenerates `docs/release-index.json`, `docs/changelog.md` and the bookmark; `bootstrap` seeds docs; `rewind` stages a demo |
| `sync-docs-to-spaces.sh` | agent, operator | mirrors the app repo's `docs/` to the Spaces bucket (`aws s3 sync --delete`) |
| `reindex-kb.sh` | agent, operator | starts a knowledge-base indexing job and waits for it |

All three operate on the app repo: set `APP_REPO_DIR` to its path, or run from inside it.
Nothing here runs on App Platform.
