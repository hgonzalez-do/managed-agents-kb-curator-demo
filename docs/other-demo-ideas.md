# Other Managed Agents demo ideas

Every idea uses Managed Agents and Serverless Inference and at least one more DO product.
Ranked by how well they show the platform's distinguishing features (sandbox, policy
engine, cron/webhooks, GitHub OAuth, checkpoints, managed secrets).

| # | Demo | What the agent does | Extra DO products | Best for |
|---|------|---------------------|-------------------|----------|
| 1 | **Docs & knowledge-base curator** (this repo) | Weekly, OpenCode harness on a DO-hosted model: read releases, write docs, regenerate index, push, re-index KB | Knowledge Bases, App Platform, Spaces | Dev-tool and API-first companies |
| 2 | **Nightly dependency & CVE fixer** | Cron: scan `package.json`/`go.mod`, bump vulnerable deps, run tests in the sandbox, open a PR. Policy requires approval for major bumps. | Container Registry, App Platform (preview deploy of the PR) | Any SaaS team; security-conscious buyers |
| 3 | **Incident triage bot** | Webhook from Uptime/Monitoring alert: pull logs via the DO API, correlate with recent deploys, draft a root-cause note and a fix PR; pause for approval before deploying | Monitoring/Uptime, App Platform, Managed Databases (read replica for queries) | Ops and platform teams |
| 4 | **Data-warehouse migration assistant** | Fork one checkpointed session into N parallel copies, each tries a migration strategy against a scratch DB; keep the winner | Managed PostgreSQL, Spaces | Companies moving off another cloud; shows checkpoints and forking |
| 5 | **Support-ticket to reproduction** | Webhook from a helpdesk: agent reproduces the bug in the sandbox with the customer's config, attaches a failing test and a suggested fix to the ticket | Knowledge Bases (product docs), App Platform | Support-heavy products |
| 6 | **Compliance evidence collector** | Monthly cron: query DO API for firewall, backup, and access settings; render an evidence pack to Spaces; open a PR to the policy repo when drift is found | Spaces, Secrets Manager | SOC 2 / ISO teams; shows least-privilege policy and managed secrets |
| 7 | **Multi-agent code review bench** | Same PR reviewed by Codex, OpenCode and Claude Code sessions side by side; Serverless Inference model router picks the summarizer | GitHub OAuth, App Platform dashboard | Shows the five-agent choice and model portability |

Selection guidance: lead with #1 for developer-tool prospects, #2 or #3 for platform
teams, #4 when the buyer cares about migrations or experimentation.
