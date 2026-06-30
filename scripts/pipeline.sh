#!/usr/bin/env bash
# Polis agent pipeline driver. Invoked one stage at a time from agent-pipeline.yml.
# Required env: ISSUE_NUMBER ISSUE_TITLE ISSUE_BODY GH_TOKEN CLAUDE_CODE_OAUTH_TOKEN REPO_OWNER
# Optional env: MAX_REVIEW_ROUNDS (default 3)
# Cross-step state (CONVERGED, TESTS_PASS) is passed via $GITHUB_ENV.
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
AGENTS_DIR="${AGENTS_DIR:-$REPO_ROOT/.github/agents}"
SKILLS_DIR="${SKILLS_DIR:-$REPO_ROOT/skills}"
MAX_REVIEW_ROUNDS="${MAX_REVIEW_ROUNDS:-3}"
POLIS_CONFIG="${POLIS_CONFIG:-$REPO_ROOT/polis.yml}"

# --- Configuration (polis.yml) -------------------------------------------------
# All helpers short-circuit to built-in defaults when no config file exists, so a
# zero-config fork never invokes yq and behaves exactly like the pre-config pipeline.

cfg_present() { [[ -f "$POLIS_CONFIG" ]]; }

# Backend name for a role: roles.<role>.backend -> defaults.backend -> "claude".
cfg_backend_for() {
  local role="$1" b="claude"
  if cfg_present; then
    b="$(yq -r ".roles.${role}.backend // .defaults.backend // \"claude\"" "$POLIS_CONFIG")"
    [[ -z "$b" || "$b" == "null" ]] && b="claude"
  fi
  echo "$b"
}

# One field of a backend definition; "" when unset. field: harness|model|base_url|api_key_env
cfg_field() {
  local backend="$1" field="$2" v=""
  if cfg_present; then
    v="$(yq -r ".backends.${backend}.${field} // \"\"" "$POLIS_CONFIG")"
    [[ "$v" == "null" ]] && v=""
  fi
  # 'claude' is a built-in backend and needs no entry to resolve its harness.
  [[ -z "$v" && "$field" == "harness" && "$backend" == "claude" ]] && v="claude"
  echo "$v"
}

# Emit "persona.md<TAB>backend" per reviewer. Defaults to the two built-in reviewers.
cfg_reviewers() {
  if cfg_present && [[ "$(yq -r '.review.reviewers // "null"' "$POLIS_CONFIG")" != "null" ]]; then
    yq -r '.review.reviewers[] | ((.persona | sub("\.md$"; "")) + ".md") + "\t" + (.backend // "claude")' "$POLIS_CONFIG"
  else
    printf 'reviewer-correctness.md\tclaude\n'
    printf 'reviewer-design.md\tclaude\n'
  fi
}

# review.max_rounds, else the env/default (preserves MAX_REVIEW_ROUNDS for zero-config).
cfg_max_rounds() {
  local r=""
  cfg_present && r="$(yq -r '.review.max_rounds // ""' "$POLIS_CONFIG")"
  if [[ -n "$r" && "$r" != "null" ]]; then
    [[ "$r" =~ ^[0-9]+$ ]] || { echo "config error: review.max_rounds must be a non-negative integer, got '$r'" >&2; exit 1; }
    echo "$r"; return
  fi
  echo "${MAX_REVIEW_ROUNDS:-3}"
}

# Configured backend names plus the built-in 'claude' (sorted, unique). No yq when zero-config.
cfg_backends() {
  { cfg_present && yq -r '.backends // {} | keys | .[]' "$POLIS_CONFIG" 2>/dev/null
    echo claude; } | sort -u
}

# True iff a fine-grained auto behavior is enabled. key: advance_spec_to_code |
# advance_arch_to_decompose | merge_when_green. Reads pipeline.auto.<key>; when unset,
# derives from pipeline.mode (auto => true, else false). Built-in default is false.
cfg_auto_mode() {
  cfg_present || { echo human; return; }
  local m; m="$(yq -r '.pipeline.mode // "human"' "$POLIS_CONFIG" 2>/dev/null)"
  [[ "$m" == "auto" ]] && echo auto || echo human
}
cfg_auto_flag() {
  local key="$1" v=""
  if cfg_present; then
    v="$(yq -r ".pipeline.auto.${key}" "$POLIS_CONFIG" 2>/dev/null)"
    [[ "$v" == "null" ]] && v=""
  fi
  [[ -z "$v" ]] && { [[ "$(cfg_auto_mode)" == "auto" ]] && v=true || v=false; }
  [[ "$v" == "true" ]]
}

# Resolve policy for the revise phase: none|all|ai-threads|fully-addressed.
# Reads pipeline.auto.resolve_policy; when unset, 'all' in auto mode else 'none'.
cfg_resolve_policy() {
  local v=""
  if cfg_present; then
    v="$(yq -r '.pipeline.auto.resolve_policy // ""' "$POLIS_CONFIG" 2>/dev/null)"
    [[ "$v" == "null" ]] && v=""
  fi
  [[ -z "$v" ]] && { [[ "$(cfg_auto_mode)" == "auto" ]] && v=all || v=none; }
  case "$v" in
    none|all|ai-threads|fully-addressed) echo "$v" ;;
    *) echo "config error: pipeline.auto.resolve_policy must be one of none|all|ai-threads|fully-addressed, got '$v'" >&2; exit 1 ;;
  esac
}

# True iff a review profile with this name is defined.
cfg_profile_exists() {
  cfg_present || return 1
  [[ "$(yq -r ".review_profiles.\"$1\" // \"null\"" "$POLIS_CONFIG" 2>/dev/null)" != "null" ]]
}

# Classify a label suffix: "" | profile | backend | none. Profile wins over backend.
cfg_suffix_kind() {
  local s="$1"
  [[ -z "$s" ]] && { echo ""; return; }
  if cfg_profile_exists "$s"; then echo profile; return; fi
  if cfg_backends | grep -qxF "$s"; then echo backend; return; fi
  echo none
}

# Default reviewer persona for an artifact (used when a profile omits persona).
_artifact_default_persona() {
  case "$1" in
    code) echo reviewer-correctness.md ;;
    spec) echo reviewer-spec.md ;;
    arch) echo reviewer-arch.md ;;
  esac
}

# Default reviewers (persona.md<TAB>backend) for an artifact, before suffix overrides.
_default_reviewers() {
  case "$1" in
    code) cfg_reviewers ;;
    spec) printf 'reviewer-spec.md\t%s\n' "$(cfg_backend_for spec_review)" ;;
    arch) printf 'reviewer-arch.md\t%s\n' "$(cfg_backend_for arch_review)" ;;
  esac
}

# Default review mode for an artifact: code = review.mode||iterate; spec/arch = comment.
_default_mode() {
  case "$1" in
    code) local m=""; cfg_present && m="$(yq -r '.review.mode // ""' "$POLIS_CONFIG")"
          [[ -n "$m" && "$m" != "null" ]] && echo "$m" || echo iterate ;;
    spec|arch) echo comment ;;
  esac
}

# Default rounds for an artifact: code = cfg_max_rounds; spec/arch = 1.
_default_rounds() { case "$1" in code) cfg_max_rounds ;; spec|arch) echo 1 ;; esac; }

# Reviewers for a review run: persona.md<TAB>backend lines.
cfg_review_reviewers() {
  local artifact="$1" suffix="$2"
  case "$(cfg_suffix_kind "$suffix")" in
    backend)
      _default_reviewers "$artifact" | while IFS=$'\t' read -r persona _b; do
        printf '%s\t%s\n' "$persona" "$suffix"; done ;;
    profile)
      local defp; defp="$(_artifact_default_persona "$artifact")"
      yq -r ".review_profiles.\"$suffix\".reviewers[] | ((.persona // \"\") + \"|\" + (.backend // \"claude\"))" "$POLIS_CONFIG" \
        | while IFS='|' read -r persona backend; do
            [[ -z "$persona" ]] && persona="$defp"
            printf '%s\t%s\n' "${persona%.md}.md" "$backend"; done ;;
    *) _default_reviewers "$artifact" ;;   # empty or none -> defaults (caller validates 'none')
  esac
}

# Review mode (comment|iterate) for a run; validated.
cfg_review_mode() {
  local artifact="$1" suffix="$2" m=""
  if [[ "$(cfg_suffix_kind "$suffix")" == profile ]]; then
    m="$(yq -r ".review_profiles.\"$suffix\".mode // \"\"" "$POLIS_CONFIG")"
    [[ "$m" == "null" ]] && m=""
  fi
  [[ -z "$m" ]] && m="$(_default_mode "$artifact")"
  case "$m" in comment|iterate) echo "$m" ;;
    *) echo "config error: review mode must be 'comment' or 'iterate', got '$m'" >&2; exit 1 ;; esac
}

# Rounds for a run.
cfg_review_rounds() {
  local artifact="$1" suffix="$2" r=""
  if [[ "$(cfg_suffix_kind "$suffix")" == profile ]]; then
    r="$(yq -r ".review_profiles.\"$suffix\".max_rounds // \"\"" "$POLIS_CONFIG")"
    if [[ -n "$r" && "$r" != "null" ]]; then
      [[ "$r" =~ ^[0-9]+$ ]] || { echo "config error: review_profiles.$suffix.max_rounds must be an integer, got '$r'" >&2; exit 1; }
      echo "$r"; return
    fi
  fi
  _default_rounds "$artifact"
}

# When skills.auto is true, emit names of all skill directories already in SKILLS_DIR.
# These were downloaded by install-harnesses.sh detect-skills.sh at job start.
cfg_auto_skills() {
  cfg_present || return 0
  [[ "$(yq -r '.skills.auto // false' "$POLIS_CONFIG" 2>/dev/null)" == "true" ]] || return 0
  [[ -d "$SKILLS_DIR" ]] || return 0
  find "$SKILLS_DIR" -maxdepth 2 -name "SKILL.md" 2>/dev/null \
    | sed "s|${SKILLS_DIR}/||; s|/SKILL.md||" | sort -u
}

# Skill names for a role: auto-detected + skills.global[] + skills.roles.<role>[], deduped.
# Prints nothing when no skills are configured or polis.yml is absent.
cfg_skills_for() {
  local role="$1"
  cfg_present || return 0
  { cfg_auto_skills
    yq -r '.skills.global // [] | .[]' "$POLIS_CONFIG" 2>/dev/null
    yq -r ".skills.roles.\"${role}\" // [] | .[]" "$POLIS_CONFIG" 2>/dev/null
  } | sort -u
}

# Build a system-prompt string from the SKILL.md files for a role's configured skills.
# Returns the empty string when no skills are configured or no SKILL.md files exist.
skills_system_prompt() {
  local role="$1" out="" skill skill_file
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    skill_file="${SKILLS_DIR}/${skill}/SKILL.md"
    [[ -f "$skill_file" ]] && out+="$(cat "$skill_file")"$'\n\n'
  done < <(cfg_skills_for "$role")
  printf '%s' "${out%$'\n\n'}"
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-50
}

add_label()    { gh issue edit "$ISSUE_NUMBER" --add-label "$1" >/dev/null 2>&1 || true; }
remove_label() { gh issue edit "$ISSUE_NUMBER" --remove-label "$1" >/dev/null 2>&1 || true; }

# Concatenate human review/comment bodies on a PR branch into one feedback blob.
pr_feedback() {
  gh pr view "$1" --json comments,reviews \
    --jq '[.reviews[]?.body, .comments[]?.body] | map(select(. != null and . != "")) | join("\n---\n")' 2>/dev/null || true
}

# Reply to (and per resolve_policy resolve) the unresolved review threads on a PR branch.
# Best-effort polish: any missing data or failed call leaves the calling stage succeeding.
reply_and_resolve() {
  local branch="$1"
  local owner="${REPO_OWNER}" repo="${REPO_NAME:-}"
  local num; num="$(gh pr list --head "$branch" --state open --json number --jq '.[0].number' 2>/dev/null || true)"
  [[ -z "$num" ]] && return 0
  local policy; policy="$(cfg_resolve_policy)"
  [[ "$policy" == none ]] && return 0   # none = silent: no agent run, no replies, no resolves

  # first:100 — not paginated; PRs with >100 unresolved threads drop the overflow
  local q='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){reviewThreads(first:100){nodes{id isResolved comments(first:1){nodes{databaseId body author{login __typename}}}}}}}}'
  local resp; resp="$(gh api graphql -f query="$q" -F owner="$owner" -F repo="$repo" -F number="$num" 2>/dev/null || true)"
  [[ -z "$resp" ]] && return 0

  # thread_id <TAB> reply_to_comment_id <TAB> author_typename <TAB> author_login <TAB> bodies
  local threads; threads="$(printf '%s' "$resp" | jq -r '
    .data.repository.pullRequest.reviewThreads.nodes[]
    | select(.isResolved==false)
    | [.id, (.comments.nodes[0].databaseId|tostring), .comments.nodes[0].author.__typename,
       (.comments.nodes[0].author.login // ""), ([.comments.nodes[].body]|join(" || "))]
    | @tsv' 2>/dev/null || true)"
  [[ -z "$threads" ]] && return 0

  # Resolve-agent prompt: the PR diff + each unresolved thread.
  local prompt; prompt="A reviser just updated this PR for issue #${ISSUE_NUMBER}. Diff:
$(git diff origin/main...HEAD 2>/dev/null || true)

Unresolved review threads (thread_id: comment):
"
  local tid rid typ login body
  while IFS=$'\t' read -r tid rid typ login body; do
    [[ -n "$tid" ]] && prompt+="- ${tid}: ${body}"$'\n'
  done <<< "$threads"
  prompt+='
Write ONLY the JSON array described in your instructions to /tmp/resolve.json — one entry per thread id above.'

  rm -f /tmp/resolve.json
  run_agent resolve resolver.md "$prompt" >/dev/null 2>&1 || true
  [[ -s /tmp/resolve.json ]] || { note "💬 Resolve agent produced no output; review threads left unchanged." 2>/dev/null || true; return 0; }

  local bot_login; bot_login="$(gh api user --jq .login 2>/dev/null || true)"
  local replied=0 resolved=0 jid jreply jstatus meta do_resolve
  while IFS=$'\t' read -r jid jreply jstatus; do
    [[ -z "$jid" ]] && continue
    meta="$(awk -F'\t' -v id="$jid" '$1==id{print; exit}' <<< "$threads")"
    [[ -z "$meta" ]] && continue
    IFS=$'\t' read -r tid rid typ login body <<< "$meta"
    [[ -z "$rid" || "$rid" == null ]] && continue   # no usable comment id: skip reply AND resolve
    gh api "repos/${owner}/${repo}/pulls/${num}/comments/${rid}/replies" -f body="$jreply" >/dev/null 2>&1 && replied=$((replied+1)) || true
    do_resolve=false
    case "$policy" in
      all)             do_resolve=true ;;
      ai-threads)      [[ "$typ" == "Bot" || ( -n "$bot_login" && "$login" == "$bot_login" ) ]] && do_resolve=true ;;
      fully-addressed) [[ "$jstatus" == "addressed" ]] && do_resolve=true ;;
      none)            do_resolve=false ;;
    esac
    if [[ "$do_resolve" == true ]]; then
      gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' -f id="$jid" >/dev/null 2>&1 && resolved=$((resolved+1)) || true
    fi
  done < <(jq -r '.[] | [.thread_id, .reply, .status] | @tsv' /tmp/resolve.json 2>/dev/null || true)

  note "💬 **Comments answered** — replied to ${replied} thread(s), resolved ${resolved} (policy: \`${policy}\`)." 2>/dev/null || true
  return 0
}

compute_vars() {
  SLUG="$(slugify "$ISSUE_TITLE")"
  BRANCH="agent/${ISSUE_NUMBER}-${SLUG}"
  SPEC_PATH="docs/specs/${ISSUE_NUMBER}-${SLUG}.md"
  ARCH_BRANCH="arch/${ISSUE_NUMBER}-${SLUG}"
  ARCH_PATH="docs/arch/${SLUG}.md"
}

# --- Harness adapters ----------------------------------------------------------
# Contract: take a persona (system prompt) + task prompt, edit files non-interactively
# with auto-approval, do NOT touch git. Only claude has a native system-prompt flag;
# codex/aider get the persona prepended to the prompt.

harness_claude() {
  local persona="$1" model="$2" skills_prompt="$3"; shift 3
  local args=(-p "$*" --append-system-prompt "$(cat "$AGENTS_DIR/$persona")"
              --dangerously-skip-permissions --output-format text)
  [[ -n "$skills_prompt" ]] && args+=(--append-system-prompt "$skills_prompt")
  [[ -n "$model" ]] && args+=(--model "$model")
  claude "${args[@]}"
}

harness_codex() {
  local persona="$1" model="$2" base_url="$3" key_env="$4" skills_prompt="$5"; shift 5
  local prompt; prompt="$(cat "$AGENTS_DIR/$persona")"
  [[ -n "$skills_prompt" ]] && prompt+=$'\n\n'"${skills_prompt}"
  prompt+=$'\n\n'"$*"
  local args=(exec)
  [[ -n "$model" ]]    && args+=(--model "$model")
  [[ -n "$base_url" ]] && args+=(-c "model_providers.custom.base_url=$base_url")
  args+=(--dangerously-bypass-approvals-and-sandbox "$prompt")
  codex "${args[@]}"
}

harness_aider() {
  local persona="$1" model="$2" base_url="$3" key_env="$4" skills_prompt="$5"; shift 5
  local prompt; prompt="$(cat "$AGENTS_DIR/$persona")"
  [[ -n "$skills_prompt" ]] && prompt+=$'\n\n'"${skills_prompt}"
  prompt+=$'\n\n'"$*"
  local args=(--message "$prompt" --yes --no-auto-commit)
  [[ -n "$model" ]] && args+=(--model "$model")
  [[ -n "$base_url" ]] && export OPENAI_API_BASE="$base_url"
  aider "${args[@]}"
}

# Dispatch a prompt to a named backend's harness.
# skills_prompt (3rd arg) is injected into the system prompt (claude) or task prompt (codex/aider).
dispatch_backend() {
  local backend="$1" persona="$2" skills_prompt="$3"; shift 3
  local harness model base_url key_env
  harness="$(cfg_field "$backend" harness)"
  model="$(cfg_field "$backend" model)"
  base_url="$(cfg_field "$backend" base_url)"
  key_env="$(cfg_field "$backend" api_key_env)"
  case "$harness" in
    claude) harness_claude "$persona" "$model" "$skills_prompt" "$*" ;;
    codex)  harness_codex  "$persona" "$model" "$base_url" "$key_env" "$skills_prompt" "$*" ;;
    aider)  harness_aider  "$persona" "$model" "$base_url" "$key_env" "$skills_prompt" "$*" ;;
    "") echo "config error: backend '$backend' is undefined or missing 'harness'" >&2; exit 1 ;;
    *)  echo "config error: unknown harness '$harness' for backend '$backend'" >&2; exit 1 ;;
  esac
}

# Revise stages resolve review threads; a bad resolve_policy must fail loudly up front
# (before the reviser runs), surfacing the error on the issue rather than aborting mid-stage.
validate_resolve_policy() {
  local err
  if ! err="$(cfg_resolve_policy 2>&1 1>/dev/null)"; then
    note "❌ ${err}" 2>/dev/null || true
    printf '%s\n' "$err" >&2
    exit 1
  fi
}

# Fail-fast: before running any agent, verify every referenced backend resolves to an
# installed harness and that its api_key_env secret (if any) is non-empty.
validate_backends() {
  cfg_present || return 0
  # Present-but-broken config is a hard error, never a silent fallback.
  if ! yq e '.' "$POLIS_CONFIG" >/dev/null 2>"${TEST_TMP:-/tmp}/polis-yqerr"; then
    local perr; perr="$(cat "${TEST_TMP:-/tmp}/polis-yqerr" 2>/dev/null || true)"
    note "❌ Polis config error: polis.yml is not valid YAML — ${perr}" 2>/dev/null || true
    printf '%s\n' "config error: polis.yml is not valid YAML: ${perr}" >&2
    exit 1
  fi
  local backends backend harness key_env
  local -a missing=()
  backends="$(
    { yq -r '.defaults.backend // ""'           "$POLIS_CONFIG"
      yq -r '.roles[].backend // ""'            "$POLIS_CONFIG"
      yq -r '.review.reviewers[].backend // ""' "$POLIS_CONFIG"
    } 2>/dev/null | sort -u )"
  while read -r backend; do
    [[ -z "$backend" ]] && continue
    harness="$(cfg_field "$backend" harness)"
    if [[ -z "$harness" ]]; then
      missing+=("backend '$backend' is referenced but not defined under backends:"); continue
    fi
    command -v "$harness" >/dev/null 2>&1 || missing+=("harness '$harness' (backend '$backend') is not installed")
    key_env="$(cfg_field "$backend" api_key_env)"
    [[ -n "$key_env" && -z "${!key_env:-}" ]] && missing+=("secret \$$key_env (backend '$backend') is empty")
  done <<< "$backends"
  if (( ${#missing[@]} )); then
    local msg="❌ Polis config/credential problem:"$'\n'
    local m; for m in "${missing[@]}"; do msg+="- ${m}"$'\n'; done
    note "$msg" 2>/dev/null || true
    printf '%s' "$msg" >&2
    exit 1
  fi
}

# Role-based entry point used by stages: resolve the role's backend, inject skills, then dispatch.
run_agent() {
  local role="$1" persona="$2"; shift 2
  local skills_prompt; skills_prompt="$(skills_system_prompt "$role")"
  dispatch_backend "$(cfg_backend_for "$role")" "$persona" "$skills_prompt" "$*"
}

note()    { gh issue comment "$ISSUE_NUMBER" --body "$1" >/dev/null; }
summary() { echo -e "$1" >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"; }

stage_spec() {
  run_agent spec spec-designer.md "Read GitHub issue #${ISSUE_NUMBER}.
Title: ${ISSUE_TITLE}
Body:
${ISSUE_BODY}

Write an implementation spec to the file ${SPEC_PATH} (create parent dirs)."
  git add "$SPEC_PATH"
  git commit -m "spec: #${ISSUE_NUMBER} ${ISSUE_TITLE}" >/dev/null
  git push -u origin "$BRANCH" --force-with-lease
  if ! gh pr view "$BRANCH" >/dev/null 2>&1; then
    gh pr create --draft --base main --head "$BRANCH" \
      --title "#${ISSUE_NUMBER}: ${ISSUE_TITLE}" \
      --body "Closes #${ISSUE_NUMBER}

Spec: \`${SPEC_PATH}\` — review it, then add **agent:revise-spec** to revise or **agent:code** to proceed."
  fi
  add_label spec-review
  note "📋 **Spec drafted** → \`${SPEC_PATH}\`. Review the draft PR, then add \`agent:revise-spec\` or \`agent:code\`."
  if cfg_auto_flag advance_spec_to_code; then
    add_label "agent:code"
    note "🤖 **Auto mode** — \`agent:code\` applied. Add \`agent:revise-spec\` to interrupt and revise the spec first."
  fi
}

stage_respec() {
  local feedback; feedback="$(pr_feedback "$BRANCH")"
  run_agent spec spec-designer.md "Revise the spec at ${SPEC_PATH} for issue #${ISSUE_NUMBER}.
Human reviewers left this feedback — address every point:
${feedback}

Rewrite ${SPEC_PATH} in place. Keep the same section structure."
  git add "$SPEC_PATH"
  git commit -m "spec: revise per review (#${ISSUE_NUMBER})" >/dev/null || echo "no spec changes"
  git push --force-with-lease
  reply_and_resolve "$BRANCH"
  note "📝 **Spec updated** per review. Re-review, then add \`agent:revise-spec\` again or \`agent:code\`."
}

stage_code() {
  run_agent code implementer.md "Implement the change described in ${SPEC_PATH} for issue #${ISSUE_NUMBER}.
Write production code AND tests. Keep changes minimal and follow existing patterns.
Do not edit files under .github/ or scripts/pipeline.sh."
  git add -A
  git commit -m "feat: #${ISSUE_NUMBER} ${ISSUE_TITLE}" >/dev/null || echo "no code changes to commit"
  summary "## Coding\nImplementation committed on \`${BRANCH}\`"
}

# Install dependencies (build.sh) then run the project's tests (test.sh).
# Build failure counts as a test failure so missing tools/deps surface clearly.
run_project_tests() {
  bash "$REPO_ROOT/scripts/build.sh" && bash "$REPO_ROOT/scripts/test.sh"
}

stage_test() {
  if run_project_tests; then
    echo "TESTS_PASS=true"  >> "$GITHUB_ENV"
    summary "## Test\n✅ build + tests passed"
  else
    echo "TESTS_PASS=false" >> "$GITHUB_ENV"
    summary "## Test\n❌ build or tests failed (check deps in scripts/build.sh)"
  fi
}

stage_open_pr() {
  git push -u origin "$BRANCH" --force-with-lease
  # Detect an existing open PR by head branch. `gh pr view "$BRANCH"` does not reliably
  # resolve a draft PR opened by an earlier `agent:spec` run, so the guard fell through,
  # `gh pr create` ran anyway, and failed under `set -e` ("a pull request … already exists") —
  # which skipped the review and stamped `agent:failed` on every spec→code sequence.
  # Querying by --head resolves reliably.
  if [[ -z "$(gh pr list --head "$BRANCH" --state open --json number --jq '.[0].number' 2>/dev/null)" ]]; then
    gh pr create --base main --head "$BRANCH" \
      --title "#${ISSUE_NUMBER}: ${ISSUE_TITLE}" \
      --body "Closes #${ISSUE_NUMBER}

Spec: \`${SPEC_PATH}\`
Generated by the Polis agent pipeline."
  fi
  gh pr ready "$BRANCH" 2>/dev/null || true   # un-draft now that code exists
}

# Run one reviewer on a backend against a described target; echoes verdict ("approve"/"block").
review_target() {
  local persona="$1" backend="$2" out="$3" target_desc="$4"
  dispatch_backend "$backend" "$persona" "" "Review ${target_desc} for issue #${ISSUE_NUMBER}.
Submit a GitHub PR review with inline comments via gh.
Then write ONLY the verdict JSON object to the file ${out}." >/dev/null
  jq -r '.verdict' "$out" 2>/dev/null || echo block
}

# Generalized review engine. comment mode: reviewers post + stop. iterate mode: loop
# review -> reviser rewrites from aggregated feedback -> (code) re-test -> push -> re-review.
run_review_recipe() {
  local artifact="$1" suffix="$2"
  local mode rounds; mode="$(cfg_review_mode "$artifact" "$suffix")"; rounds="$(cfg_review_rounds "$artifact" "$suffix")"
  [[ "$mode" == comment ]] && rounds=1
  local -a reviewers=(); local _r
  while IFS= read -r _r; do reviewers+=("$_r"); done < <(cfg_review_reviewers "$artifact" "$suffix")

  local target_desc reviser_role reviser_persona doc_path="" run_tests=0
  case "$artifact" in
    code) target_desc="the diff of the current PR branch (run 'git diff origin/main...HEAD' and 'gh pr view')"
          reviser_role=fix;       reviser_persona=fixer.md;        run_tests=1 ;;
    spec) target_desc="the spec document at ${SPEC_PATH} on the current branch"
          reviser_role=spec;      reviser_persona=spec-designer.md; doc_path="$SPEC_PATH" ;;
    arch) target_desc="the architecture document at ${ARCH_PATH} on the current branch"
          reviser_role=architect; reviser_persona=architect.md;     doc_path="$ARCH_PATH" ;;
  esac

  local round i entry persona backend verdict rsum name all_approve note_line summaries
  for (( round=1; round<=rounds; round++ )); do
    summary "## ${artifact} review round ${round}/${rounds} (${mode})"
    all_approve=true; summaries=""; note_line="🔍 **${artifact} review ${round}/${rounds}** —"
    i=0
    for entry in "${reviewers[@]}"; do
      IFS=$'\t' read -r persona backend <<<"$entry"
      local out="/tmp/review-${i}.json"; rm -f "$out"
      verdict="$(review_target "$persona" "$backend" "$out" "$target_desc")"
      rsum="$(jq -r '.summary' "$out" 2>/dev/null || echo '')"
      name="${persona%.md}"
      [[ "$verdict" != approve ]] && all_approve=false
      note_line+=" ${name}: ${verdict};"
      summary "- ${name} (${backend}): **${verdict}** — ${rsum}"
      summaries+="${name} review: ${rsum}"$'\n'
      i=$((i+1))
    done
    note "$note_line"
    if [[ "$all_approve" == true ]]; then echo "CONVERGED=true" >> "$GITHUB_ENV"; return 0; fi
    if [[ "$mode" == comment ]]; then echo "CONVERGED=false" >> "$GITHUB_ENV"; return 0; fi
    local revise_prompt
    if [[ -n "$doc_path" ]]; then
      revise_prompt="Reviewers requested changes to ${doc_path} for issue #${ISSUE_NUMBER}.
${summaries}
Rewrite ${doc_path} in place addressing every point; keep its structure."
    else
      revise_prompt="Reviewers requested changes on issue #${ISSUE_NUMBER}.
${summaries}
Apply minimal fixes addressing this feedback."
    fi
    run_agent "$reviser_role" "$reviser_persona" "$revise_prompt"
    if [[ -n "$doc_path" ]]; then git add "$doc_path" || true; else git add -A || true; fi
    local ctype; case "$artifact" in code) ctype=fix ;; *) ctype="$artifact" ;; esac  # conventional-commit type
    git commit -m "${ctype}: address review round ${round} (#${ISSUE_NUMBER})" >/dev/null || true
    [[ "$run_tests" == 1 ]] && { run_project_tests >/dev/null 2>&1 || true; }
    git push --force-with-lease 2>/dev/null || true
  done
  echo "CONVERGED=false" >> "$GITHUB_ENV"
}

# Suffix from a review label like agent:spec_review:codex ("" for a bare label).
review_suffix() {
  local prefix="agent:${1}_review"
  case "${LABEL_NAME:-}" in
    "$prefix":*) echo "${LABEL_NAME#"$prefix":}" ;;
    *) echo "" ;;
  esac
}

# Hard error if a non-empty suffix resolves to neither a backend nor a profile.
_validate_suffix() {
  local artifact="$1" suffix="$2"
  [[ -z "$suffix" ]] && return 0
  [[ "$(cfg_suffix_kind "$suffix")" == none ]] || return 0
  note "❌ Review label suffix '${suffix}' is neither a configured backend nor a defined profile." 2>/dev/null || true
  echo "config error: unknown review suffix '${suffix}'" >&2; exit 1
}

stage_code_review() { local s; s="$(review_suffix code)"; _validate_suffix code "$s"; run_review_recipe code "$s"; }
stage_spec_review() { local s; s="$(review_suffix spec)"; _validate_suffix spec "$s"; run_review_recipe spec "$s"; }
stage_arch_review() { local s; s="$(review_suffix arch)"; _validate_suffix arch "$s"; run_review_recipe arch "$s"; }

# agent:code auto-review entry point (unchanged behavior).
stage_review_loop() { run_review_recipe code ""; }

stage_human_fix() {
  local feedback; feedback="$(pr_feedback "$BRANCH")"
  local instruction
  if [[ -n "$feedback" ]]; then
    instruction="Human reviewers left feedback on the PR for issue #${ISSUE_NUMBER}.
Address every point with minimal changes:
${feedback}"
  else
    # No comment was left — treat agent:revise-code as 'make the failing tests pass'.
    instruction="No written feedback was left on the PR for issue #${ISSUE_NUMBER}.
Run scripts/test.sh, diagnose why it fails, and apply minimal changes to make every test pass."
  fi
  run_agent fix fixer.md "$instruction"
  git add -A
  git commit -m "fix: address human review (#${ISSUE_NUMBER})" >/dev/null || echo "no changes"
  git push --force-with-lease
  reply_and_resolve "$BRANCH"
  if run_project_tests >/dev/null 2>&1; then
    remove_label tests-failing
    add_label needs-human-review
    note "🔧 **Applied fixes** — tests now **passing** ✅. Re-review, or merge when satisfied."
  else
    add_label tests-failing
    add_label needs-human-review
    note "🔧 **Applied fixes** — tests still **failing** ❌. Add a PR comment with more detail and re-apply \`agent:revise-code\`, or inspect the Actions run."
  fi
}

stage_finalize() {
  local converged="${CONVERGED:-false}" tests_ok="${TESTS_PASS:-true}"
  local reviews="" i=0 persona backend
  while IFS=$'\t' read -r persona backend; do
    reviews+="- **${persona%.md}:** $(jq -r '.summary' "/tmp/review-${i}.json" 2>/dev/null || echo n/a)"$'\n'
    i=$((i+1))
  done < <(cfg_reviewers)

  if cfg_auto_flag merge_when_green && [[ "$converged" == "true" && "$tests_ok" == "true" ]]; then
    gh pr comment "$BRANCH" --body "$(cat <<EOF
## 🤖 Agent pipeline summary (auto mode)
- **Status:** converged ✅
- **Tests:** passing
- **Spec:** \`${SPEC_PATH}\`

### Final reviews
${reviews}
Auto-merging — all checks passed.
EOF
)" || true
    gh pr merge "$BRANCH" --squash --delete-branch 2>/dev/null || true
    note "✅ **Auto-merged** — all reviewers approved and tests passing."
    return 0
  fi

  local labels="needs-human-review"
  [[ "$converged" == "false" ]] && labels="${labels},agent:cap-reached"
  [[ "$tests_ok"  == "false" ]] && labels="${labels},tests-failing"
  gh pr edit "$BRANCH" --add-label "$labels" || true
  gh pr edit "$BRANCH" --add-reviewer "$REPO_OWNER" 2>/dev/null || true
  gh pr comment "$BRANCH" --body "$(cat <<EOF
## 🤖 Agent pipeline summary
- **Status:** $([[ "$converged" == "true" ]] && echo "converged ✅" || echo "hit round cap ⚠️")
- **Tests:** $([[ "$tests_ok" == "true" ]] && echo "passing" || echo "failing ❌")
- **Spec:** \`${SPEC_PATH}\`

### Final reviews
${reviews}
Ready for human review.
EOF
)" || true
  note "✅ **Ready for human review** — PR labeled \`needs-human-review\`."
}

stage_arch() {
  run_agent architect architect.md "Read GitHub issue #${ISSUE_NUMBER} (the product idea).
Title: ${ISSUE_TITLE}
Body:
${ISSUE_BODY}

Write an architecture document to ${ARCH_PATH} (create parent dirs). It MUST end with a
'## Work breakdown' section using this exact format so it can be parsed:
  - Phase 1: <phase name>
    - <issue title>
    - <issue title>
  - Phase 2: <phase name>
    - <issue title>"
  git add "$ARCH_PATH"
  git commit -m "arch: #${ISSUE_NUMBER} ${ISSUE_TITLE}" >/dev/null
  git push -u origin "$ARCH_BRANCH" --force-with-lease
  if ! gh pr view "$ARCH_BRANCH" >/dev/null 2>&1; then
    gh pr create --draft --base main --head "$ARCH_BRANCH" \
      --title "arch: #${ISSUE_NUMBER} ${ISSUE_TITLE}" \
      --body "Architecture for #${ISSUE_NUMBER}.
Review \`${ARCH_PATH}\`, then add **agent:revise-arch** to revise or **agent:decompose** to create the issues."
  fi
  add_label arch-review
  note "🏛️ **Architecture drafted** → \`${ARCH_PATH}\`. Review the draft PR, then add \`agent:revise-arch\` or \`agent:decompose\`."
  if cfg_auto_flag advance_arch_to_decompose; then
    add_label "agent:decompose"
    note "🤖 **Auto mode** — \`agent:decompose\` applied. Add \`agent:revise-arch\` to interrupt and revise first."
  fi
}

stage_rearch() {
  local feedback; feedback="$(pr_feedback "$ARCH_BRANCH")"
  run_agent architect architect.md "Revise the architecture document at ${ARCH_PATH} for #${ISSUE_NUMBER}.
Human reviewers left this feedback — address every point:
${feedback}

Rewrite ${ARCH_PATH} in place. Keep the '## Work breakdown' section and its exact format."
  git add "$ARCH_PATH"
  git commit -m "arch: revise per review (#${ISSUE_NUMBER})" >/dev/null || echo "no arch changes"
  git push --force-with-lease
  reply_and_resolve "$ARCH_BRANCH"
  note "📝 **Architecture updated** per review. Re-review, then add \`agent:revise-arch\` again or \`agent:decompose\`."
}

# Emit "PHASE<TAB>ISSUE_TITLE" for each issue under '## Work breakdown'.
parse_breakdown() {
  awk '
    /^## Work breakdown/ {inwb=1; next}
    inwb && /^## / {inwb=0}
    inwb && /^[[:space:]]*-[[:space:]]*Phase[[:space:]]/ {
      sub(/^[[:space:]]*-[[:space:]]*/, ""); phase=$0; next }
    inwb && /^[[:space:]]+-[[:space:]]/ {
      sub(/^[[:space:]]+-[[:space:]]*/, ""); if (phase!="") print phase "\t" $0 }
  ' "$1"
}

stage_decompose() {
  git fetch -q origin "$ARCH_BRANCH" && git checkout -q "$ARCH_BRANCH"
  local phase title last_phase="" map="### Decomposed issues"
  while IFS=$'\t' read -r phase title; do
    [[ -z "$title" ]] && continue
    if [[ "$phase" != "$last_phase" ]]; then
      gh api "repos/${GITHUB_REPOSITORY:-${REPO_OWNER}/${REPO_NAME:-}}/milestones" \
        -f title="$phase" >/dev/null 2>&1 || true
      last_phase="$phase"; map+=$'\n'"**${phase}**"
    fi
    local url
    url="$(gh issue create --title "$title" --milestone "$phase" \
      --body "Part of the architecture for #${ISSUE_NUMBER} (${phase}).

$title

Add \`agent:spec\` when ready to refine this into a spec.")"
    map+=$'\n'"- ${title} — ${url}"
  done < <(parse_breakdown "$ARCH_PATH")
  note "$map"
}

main() {
  local STAGE="${1:?stage required (arch|rearch|decompose|spec|respec|code|test|open-pr|review|code-review|spec-review|arch-review|human-fix|finalize)}"
  compute_vars
  case "$STAGE" in
    decompose|test|open-pr) : ;;   # no agents -> skip backend validation
    *) validate_backends ;;
  esac
  case "$STAGE" in
    respec|rearch|human-fix) validate_resolve_policy ;;
  esac
  case "$STAGE" in
    arch)         stage_arch ;;
    rearch)       stage_rearch ;;
    decompose)    stage_decompose ;;
    spec)         stage_spec ;;
    respec)       stage_respec ;;
    code)         stage_code ;;
    test)         stage_test ;;
    open-pr)      stage_open_pr ;;
    review)       stage_review_loop ;;
    code-review)  stage_code_review ;;
    spec-review)  stage_spec_review ;;
    arch-review)  stage_arch_review ;;
    human-fix)    stage_human_fix ;;
    finalize)     stage_finalize ;;
    *) echo "unknown stage: $STAGE" >&2; exit 1 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
