#!/usr/bin/env bash
# Install the agent harnesses this fork actually uses. Always installs claude.
# When polis.yml is present, installs yq and every harness referenced under
# backends[].harness (deduped). Idempotent; safe to run at the top of every job.
set -euo pipefail
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Restore Codex's ChatGPT-subscription credentials (what `codex login` writes to
# ~/.codex/auth.json) from the CODEX_AUTH secret, so the codex harness can use a
# subscription instead of a metered OPENAI_API_KEY — the analog of CLAUDE_CODE_OAUTH_TOKEN.
# No-op when CODEX_AUTH is unset. Honors CODEX_HOME (codex's own location override).
# Note: codex refreshes the token in-run only; it can't persist back to the secret,
# so re-export auth.json into CODEX_AUTH if it expires.
restore_codex_auth() {
  [[ -n "${CODEX_AUTH:-}" ]] || return 0
  local dir="${CODEX_HOME:-$HOME/.codex}"
  mkdir -p "$dir"
  printf '%s' "$CODEX_AUTH" > "$dir/auth.json"
  chmod 600 "$dir/auth.json"
  echo "install-harnesses: restored Codex auth to $dir/auth.json"
}

npm install -g @anthropic-ai/claude-code

CONFIG="$REPO_ROOT/polis.yml"
[[ -f "$CONFIG" ]] || { echo "install-harnesses: no polis.yml, claude only"; exit 0; }

if ! command -v yq >/dev/null 2>&1; then
  sudo wget -qO /usr/local/bin/yq \
    https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  sudo chmod +x /usr/local/bin/yq
fi

# Process substitution (not a pipe) keeps the loop in the current shell, so the
# unknown-harness `exit 1` aborts the job. No mapfile → runs on bash 3.2 too.
while IFS= read -r h; do
  case "$h" in
    claude|"") : ;;  # claude already installed; "" = backend with no harness field
    codex)  npm install -g @openai/codex; restore_codex_auth ;;
    aider)  pipx install aider-chat || pip install --user aider-chat ;;
    *) echo "install-harnesses: unknown harness '$h' in polis.yml" >&2; exit 1 ;;
  esac
done < <(yq -r '.backends[].harness' "$CONFIG" 2>/dev/null | sort -u)
