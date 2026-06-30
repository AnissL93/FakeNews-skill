---
name: drive
description: Drive the Polis agent pipeline end-to-end from the terminal — list issues/PRs and their stage, create issues, apply any agent:* trigger label (plan / spec / code / fix / review), watch the Actions run, read review feedback, and merge — without touching the GitHub web UI. Use when the user wants to run, drive, advance, or check the Polis pipeline.
---

# Drive the Polis pipeline

An interactive **cockpit** for the Polis pipeline. Run it as a loop: show the state panel →
the user picks an action → apply it via `gh` → (optionally) watch the run → refresh the panel.
The goal is to drive everything from Claude Code; the user never opens github.com. You only
**trigger** and **report** — the actual work runs in GitHub Actions (workflow **"Agent Pipeline"**).

## Loop

Repeat until the user says they're done:
1. Render the **State panel** (below).
2. Ask the user what to do (AskUserQuestion) — offer the suggested next action first.
3. Run the chosen action via `gh`. **Confirm before any action that triggers a cloud run or merges.**
4. If it triggered a run and the user wants, **watch** it; otherwise refresh the panel.

## Step 0 — Preflight

- `command -v gh` — if missing, tell the user to install it and stop.
- `gh auth status` — if not logged in, ask them to run `! gh auth login`, then re-check.
- Resolve the repo: `gh repo view --json nameWithOwner -q .nameWithOwner` (run from the repo, or
  pass `--repo OWNER/NAME`). Confirm it's a Polis repo before triggering anything —
  `gh api repos/{owner}/{repo}/contents/scripts/pipeline.sh >/dev/null` must succeed; if it doesn't,
  stop (wrong repo).

## State panel

Build it from `gh` (read-only):
- Issues: `gh issue list --state open --json number,title,labels --limit 30`.
- PRs: `gh pr list --state open --json number,title,labels,headRefName,isDraft,reviewDecision --limit 30`.

For each issue/PR show: number, title, current `agent:*` + status labels, the computed **stage**,
and the **suggested next action** from the stage graph below. Group by "needs you" (has a
status label awaiting a human) vs "in flight".

### Stage graph (what to suggest next)

| Current signal | Stage | Suggested next |
|----------------|-------|----------------|
| New issue, no PR, reads like a big idea | idea | `agent:arch` (plan) or `agent:spec` (single unit) |
| `arch-review` label / open `arch/*` PR | arch drafted | `agent:revise-arch` (revise) or `agent:decompose` (make issues) |
| Generated issue, no spec PR yet | ready to spec | `agent:spec` |
| `spec-review` label / draft `agent/*` PR with a spec | spec drafted | `agent:revise-spec` (revise) or `agent:code` (implement) |
| Open `agent/*` PR, `needs-human-review`, tests passing | code ready | review feedback → **merge**, or `agent:revise-code` |
| PR with `tests-failing` | tests red | `agent:revise-code` (no comment = make tests pass) |
| PR with `agent:cap-reached` | review loop capped | read verdicts → `agent:revise-code`, or re-run AI review with `agent:code_review[:<profile>]`, or merge |
| `agent:failed` | run errored | `gh run view <id> --log-failed` to see the error, fix the cause, then re-apply the original trigger label |

Always offer the on-demand review triggers too (next section).

> **Reading `agent:failed` correctly.** Inspect the failed step before assuming the work was lost —
> the failure is often benign and the code/spec already landed:
> - **`open-pr` failed with "a pull request … already exists"** (older scaffolds before the
>   `gh pr list --head` guard): the `agent:code` run pushed code and ran tests fine, but the
>   `open-pr` step collided with the draft PR that `agent:spec` already opened, which skipped the
>   AI review. The PR has the code. **Recover:** clear `agent:failed`, then run `agent:code_review`
>   on the issue to get the review that was skipped (no re-implementation needed).
> - **`Checkout the issue branch` failed** (`pathspec did not match`): `agent:code` was applied to an
>   issue that never went through `agent:spec`, so the branch does not exist. **Recover:** clear
>   `agent:failed`, run `agent:spec` first, then `agent:code`.

## Actions

All label changes: `gh issue edit <n> --add-label "<label>"` (remove with `--remove-label`).
The pipeline triggers on the **labeled** event, so adding the label is the trigger.

- **Kick off from an idea:** `gh issue create --title "<title>" --body "<idea>"`, then offer
  `agent:arch` or `agent:spec` on the new issue.
- **Planning:** `agent:arch` / `agent:revise-arch` / `agent:decompose` (on the parent issue).
- **Execution:** `agent:spec` / `agent:revise-spec` / `agent:code` / `agent:revise-code` (on the generated issue). Under a non-`none` `resolve_policy`, the revise stage also replies to and resolves review threads automatically.
  **`agent:spec` must run before `agent:code` on an issue** — the `spec` job creates the
  `agent/<n>-<slug>` branch (`git checkout -b`); the `code` job only checks it out. Labelling a
  never-spec'd issue `agent:code` fails at "Checkout the issue branch" (`pathspec did not match`)
  and stamps `agent:failed`. There is no "code without spec" shortcut — recover by clearing
  `agent:failed` and running `agent:spec` first.
- **On-demand review:** `agent:code_review` / `agent:spec_review` / `agent:arch_review`, optionally
  with a `:<backend|profile>` suffix. Read the valid suffixes **from `polis.yml`** so you only offer
  real ones: list backend names under `backends:` (plus the built-in `claude`) and profile names
  under `review_profiles:`. (Read the file directly and parse it; if there is no `polis.yml`, the
  only suffix is `claude`.) Present them as a submenu. Note: `agent:arch_review` (underscore, a
  trigger) is different from `arch-review` (hyphen, a pipeline status label) — don't conflate them.
- **Merge (terminal human gate):** for a PR the user is satisfied with, `gh pr merge <n> --squash`
  (ask squash/merge/rebase). **Always confirm first** — show the PR title + reviewDecision.
- **Escape hatch:** apply or remove any arbitrary label the user names — **except** the pipeline
  status labels listed under Safety (those are outputs; applying them by hand corrupts state). If
  the user asks for one of those, decline and explain.

Only the repo owner (or `vars.PIPELINE_OWNER`) can trigger the pipeline — if the user isn't the
owner, applying a label will no-op in Actions; mention this if their runs don't start.

## Watch a run

The labeled event starts a run of **"Agent Pipeline"**. Runs are **not tagged with the issue
number** and several can be in flight at once, so do NOT just watch the latest run — anchor on the
moment you applied the label and confirm the matched run before watching:
```bash
BEFORE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
gh issue edit <n> --add-label "<label>"          # the trigger
ID=""
for _ in 1 2 3 4 5; do                            # allow a few seconds' lag for the run to appear
  ID=$(gh run list --workflow "Agent Pipeline" --event issues \
        --json databaseId,createdAt,displayTitle \
        --jq "[.[] | select(.createdAt >= \"$BEFORE\")][0].databaseId // empty")
  [[ -n "$ID" ]] && break
  sleep 3
done
[[ -n "$ID" ]] && gh run watch "$ID" --exit-status || echo "run not found yet — check 'gh run list'"
```
Show the matched run's `displayTitle` so the user can confirm it's theirs before watching. The
`// empty` keeps an empty result truly empty (never `gh run watch null`). Report success/failure;
on failure offer `gh run view "$ID" --log-failed` to surface the error.

## Show review / PR feedback

To decide rearch/respec/fix/merge without leaving the terminal:
```bash
gh pr view <n> --json title,reviewDecision,comments,reviews \
  --jq '{title, reviewDecision, reviews: [.reviews[] | {author: .author.login, state, body}], comments: [.comments[].body]}'
```
Summarize the agent's review verdicts and any human comments, then suggest the next label.

## Safety

- **Confirm before** applying a trigger label (it spends a cloud run) and **before merging**.
- Never apply pipeline-applied **status** labels (`needs-human-review`, `tests-failing`,
  `arch-review`, `spec-review`, `agent:cap-reached`, `agent:failed`) — those are outputs, not triggers.
- Removing the trigger label is unnecessary; the pipeline removes it itself at run start.
- Read-only commands (list/view/watch) need no confirmation.

## Done

When the user is finished, summarize what was triggered this session (issues touched, labels
applied, merges) and any runs still in progress they may want to check later.
