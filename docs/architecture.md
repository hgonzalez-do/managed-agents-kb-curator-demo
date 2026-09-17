# Architecture

Two loops share one knowledge base. The **curation loop** runs weekly with no human in it.
The **answer loop** runs on every chat message.

```mermaid
flowchart TB
  subgraph Curation loop — weekly, unattended
    CRON[Cron trigger\nMon 09:00 UTC] --> MA[Managed Agent session\nClaude Code in an isolated sandbox]
    GH_SRC[(GitHub\ndigitalocean/doctl releases)] -->|releases.py fetch| MA
    MA -->|writes docs/releases/*.md\nregenerates release-index.json + changelog| REPO[(GitHub\nhgonzalez-do/doctl-support-bot)]
    MA -->|aws s3 sync docs/| SP[(Spaces bucket)]
    MA -->|POST /v2/gen-ai/indexing_jobs| KB[Gradient Knowledge Base]
    SP --> KB
    MA -.->|model calls| SI
  end

  subgraph Answer loop — per request
    U[User] --> APP[App Platform\ndoctl-support-bot]
    APP -->|POST /v1/kb/retrieve| KB
    APP -->|POST /v1/chat/completions| SI[Serverless Inference]
    APP --> U
  end

  REPO -->|deploy on push| APP
  SM[(Secrets Manager)] -. spec.secrets .-> MA
```

## Components and the DO products behind them

| Piece | DO product | Notes |
|---|---|---|
| Curator | **Managed Agents** | Claude Code agent, cron trigger, GitHub OAuth, policy engine, managed secrets |
| Curator's model | **Serverless Inference** | The agent's own reasoning uses a DO-hosted model via the OpenAI/Anthropic-compatible endpoint |
| Chatbot model | **Serverless Inference** | `INFERENCE_MODEL`, swappable at runtime without code changes |
| Retrieval | **Gradient Knowledge Bases** | Hybrid search, standalone retrieve API, no agent required |
| Document store | **Spaces** | KB data source; agent syncs `docs/` after each run |
| Hosting | **App Platform** | Deploys on push; redeploy refreshes `/api/releases` |
| Credentials | **Secrets Manager** | Populated from `spec.secrets`; never in `spec.env` or logs |

## Why this shape

- **Docs in git, not just in the KB.** Every change the agent makes is a commit a human can
  review, revert or diff. The KB is a projection of the repo.
- **A deterministic core with an LLM around it.** `releases.py` does fetching, parsing and
  index regeneration. The agent's judgment is spent on the part that needs it: writing
  summaries and upgrade notes a support engineer would want.
- **Retrieval separated from generation.** The bot calls the KB retrieve API directly and
  passes chunks to Serverless Inference. Model choice is a config value.
- **Least privilege by construction.** The app runs with a GenAI-read token. The agent
  has one repo, one bucket prefix and one KB. Policy denies network egress it does not need.

## The "OpenAPI spec" step, adapted

The original brief regenerates an OpenAPI spec. doctl is a CLI, so the equivalent
machine-readable artifact here is `docs/release-index.json`, which the app serves at
`/api/releases`. For an API-first customer, swap that step for regenerating their spec
from source and dropping it into `docs/` so it is indexed too.
