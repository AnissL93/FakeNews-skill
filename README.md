# FakeNews-skill

Powered by [Polis](https://github.com/AnissL93/Polis) — an issue-driven, human-in-the-loop
agent pipeline. Open an issue describing an idea, then drive it with labels (or `/drive` in
Claude Code).

| Add label | The agent… |
|-----------|------------|
| `agent:arch` / `agent:rearch` / `agent:decompose` | plan: architecture doc, then issues |
| `agent:spec` / `agent:respec` | write / revise a spec |
| `agent:code` / `agent:fix` | implement code + tests, run an AI review loop |

You never hand-edit `scripts/build.sh` / `test.sh` / `deploy.sh` — the agent writes them to
match your stack.
