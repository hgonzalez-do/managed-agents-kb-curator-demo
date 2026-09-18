# Live demo script (about 8 minutes)

Audience: developer-tool and API-first companies. Message: "your docs and your support
bot stay current without anyone on your team doing it, and it all runs on DigitalOcean."

## Before the session

1. Everything deployed (`scripts/00` through `04`). Chatbot URL open in a tab.
2. Stage the gap: `scripts/05-demo-rewind.sh 1`. The KB now lacks the newest doctl release.
3. Have the Managed Agents console and a terminal ready.

## Walkthrough

**1. The problem (1 min).** Open the chatbot. Ask: *"What changed in doctl v1.168.0?"*
The bot says it does not have that release. The header shows "docs current through v1.167.0".
Point out the sources it cites: this is real retrieval, not a model guessing.

**2. What is running (1 min).** Show `docs/architecture.md` diagram. Two loops, one
knowledge base. Name the products: Managed Agents, Serverless Inference, Knowledge Bases,
App Platform, Spaces.

**3. Trigger the agent (30 s).** Instead of waiting for Monday's cron, run
`scripts/06-run-curator-now.sh`. It starts a fresh session from the same spec the trigger
uses and attaches. Paste the one-line prompt it prints. (Or, if you created the webhook
trigger, publish a release on a fork of doctl and let GitHub fire it.)

**4. Watch it work (3 min).** Narrate as the terminal streams:
- It pulls the repo and runs `releases.py fetch`: one new release found.
- It reads the commit list and writes `docs/releases/v1.168.0.md` with a real summary
  ("adds simulation APIs; fixes `databases resize --wait` returning early").
- It regenerates `release-index.json` and `changelog.md`, commits, pushes.
  Show the commit on GitHub. Mention: the agent never held a GitHub token; that is the
  platform's OAuth connection and the policy engine allowed exactly `git push origin main`.
- It syncs Spaces and starts a KB indexing job. Show the job in the console.
- It runs the retrieval check and prints the final report.

**5. The payoff (1 min).** Back to the chatbot. Same question. Now it answers with the
version, the date, both changes, and cites `v1.168.0.md`. Header now says v1.168.0.
App Platform redeployed on push so `/api/releases` is also current.

**6. Controls (1 min).** Open `agent/spec.yaml`:
- `secrets:` vs `env:` (Secrets Manager; nothing sensitive is debug-readable). `GITHUB_TOKEN`
  is `oauth/github`: no PAT anywhere.
- `permissions:` allow by default, explicit `deny` rules. For an attended session, set
  `default: ask` and a `git push` rule with `action: ask`; the run pauses for a human.
- `skills:` the runbook rides along with the agent; the trigger prompt is one sentence.
- Triggers: `doctl agent triggers list` shows the weekly cron; `list-executions` shows each
  run with its session ID, so `doctl agent logs <session>` replays the transcript.
- Checkpoints: `doctl agent checkpoint create` then `fork --count 3` to try three summary
  styles in parallel without losing the run.

## Talking points if asked

- *Cost:* the session pauses between runs; you pay for minutes worked. Inference is per token.
- *Why not put the KB behind a Gradient Agent?* You can. Here the app owns the prompt
  and picks the model, which is what dev-tool teams usually want.
- *Swap the source:* any repo with releases, PRs or a CHANGELOG. Swap `SOURCE_REPO`
  and the parser regex; the rest is unchanged.
- *Human in the loop:* change step 6 of the prompt to open a PR instead of pushing to
  `main`, and set the policy to require approval on push.

## Reset after the demo

`scripts/05-demo-rewind.sh 1` again, or leave it: next Monday's cron finds nothing new.
