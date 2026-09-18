# Variant: Action Gateway instead of tokens in the sandbox

The default design gives the curator three credentials as managed secrets: a GitHub token,
a DigitalOcean API token and a Spaces key pair. They are stored in Secrets Manager and are
never logged, but they do exist inside the sandbox as environment variables, so the agent
process can read them.

Action Gateway removes that class of exposure. Tools run through a managed MCP endpoint;
the gateway resolves credentials at execution time, so they never enter the sandbox or the
model context, and every tool call is traced in the Action Gateway Insights tab.

## What changes

| Step in the runbook | Default (today) | Action Gateway variant |
|---|---|---|
| Read doctl releases | `releases.py fetch` (public GitHub API, no auth) | same, or `exa_web_fetch` |
| Write docs + commit + push | `git` with `GITHUB_TOKEN` in the sandbox | GitHub tool: create/update file contents via the API; no token in the sandbox |
| Sync to Spaces | `aws s3 sync` with Spaces keys in the sandbox | unchanged today (no Spaces tool in the catalog yet), or `mounts: s3fuse` once enforced |
| Start / poll KB indexing job | `curl` with `DIGITALOCEAN_ACCESS_TOKEN` | DigitalOcean infrastructure actions tool |
| Retrieval check | `curl` to kbaas with the DO token | DigitalOcean actions tool, or drop the check |

## Spec changes

```yaml
tools:
  - do.actions: [github, exa_web_fetch]      # or a pinned toolbelt: [toolbelt:doctl-curator@1]
permissions:
  default: allow
  rules:
    - tool: mcp
      action: allow
    # keep the bash deny rules; drop the git rules once git is no longer used
secrets:
  HARNESS_INFERENCE_API_KEY: "<model key>"   # the only secret left in the sandbox
```

Connect GitHub to Action Gateway once (console: Managed Agents -> Action Gateway ->
Connections), or let it prompt at first use. With Open Harness you do not manage Actors,
Sessions or Toolbelts yourself.

## Why it is not the default yet

- `tools:` in the agent spec is accepted but not yet enforced in the current preview.
- Committing many files through the GitHub API is slower and noisier than one `git push`, and
  loses the atomic commit. Fine for one or two release pages per week; check the tool's
  capabilities before relying on it.
- Spaces and knowledge-base indexing still need a DO token in the sandbox unless the
  DigitalOcean actions tool covers `gen-ai/indexing_jobs`.

## When to show it

Bring it up when the audience's objection is "I do not want a GitHub token in a sandbox."
Show the commented `tools:` block, the Connections page, and the Insights trace of a tool
call. Then say the default design is what runs unattended today, and this is the upgrade path.
