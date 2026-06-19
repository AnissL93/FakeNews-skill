# Spec: Update project documentation (README, inline docs, CHANGELOG)

## Problem

Issue #30 asks for a full documentation sweep so the three human-facing artefacts
match the current implementation:

1. **README.md** — today it is generic Polis pipeline boilerplate and says nothing
   about the fake-news-detector skill this repo actually ships. It must describe the
   current feature set (overall credibility scoring, the five detection passes,
   verbatim quote extraction, the user-friendly summary layer, prompt-injection
   hardening) and show a usage example with sample output.
2. **Inline docs** — module- and function-level docstrings across the source files.
   The only real source code is `scripts/validate_skill.py` (685 lines, ~30 helper
   functions, most currently undocumented). Its docstrings should be added/refreshed.
3. **CHANGELOG.md** — does not exist; create one from the git history, covering the
   feature work merged in commits/PRs #11–#16.

Acceptance is that all three artefacts are updated and consistent with the
implementation as it stands on `main`.

## Approach

This is a documentation-only change. No skill behaviour, reference files, or
validator logic changes — so the existing skill validation must keep passing
unchanged.

**README.md** — rewrite into a project README for the fake-news-detector skill while
keeping a short pointer to the Polis pipeline at the bottom (don't delete the
existing maintenance note — the build/test/deploy scripts are still agent-managed).
Add: a one-paragraph description; a "What it checks" section listing the five
detection dimensions (Factual red flag, Bias & framing, Logical fallacy,
Clickbait / hype, Narrative manipulation) plus the credibility rating bands
(Credible, Mostly Credible, Mixed, Low Credibility, Not Credible); a note that each
finding cites a verbatim quote and that analyzed text is treated as untrusted data
(prompt-injection hardening); a "Usage" section showing how the skill is triggered
and a fenced sample output block following the `## Verdict` / `## Findings` /
`## Rationale` template from `references/output-format.md`. Keep all feature names and
band labels copied verbatim from the reference files so the README stays consistent.

**Inline docs** — add a concise one-line (or short) docstring to each top-level
function in `scripts/validate_skill.py` that lacks one, describing what it validates
or returns. Keep the existing module docstring (refresh only if needed). Do not change
any executable logic, signatures, or behaviour — docstrings only. The shell scripts
already carry header comments and need no change.

**CHANGELOG.md** — create a new file in [Keep a Changelog](https://keepachangelog.com)
style with an `## [Unreleased]` section, an `### Added` list summarising the
feature work from the git log. At minimum one entry per PR #11–#16 (findings format
with verbatim quotes; overall credibility scoring & rationale synthesis; user-friendly
summary layer; prompt-injection hardening; misleading/credible sample fixtures;
fixture acceptance check). Entries should be plain-language and reference the issue
numbers.

Apply YAGNI: do not add a docs build system, a CHANGELOG-generation script, or
automated README/CHANGELOG validation. The skill validator stays the authoritative
test and is only run to confirm no regression.

## Affected files

- `README.md` — rewrite to describe the skill, its features, and a usage example.
- `CHANGELOG.md` — new file; Keep-a-Changelog format covering #11–#16.
- `scripts/validate_skill.py` — add/refresh module and function docstrings (no logic change).

## Test plan

Run command (authoritative for `scripts/test.sh`): `bash scripts/build.sh && bash scripts/test.sh`

- [ ] `bash scripts/build.sh && bash scripts/test.sh` exits 0 — skill validation still
      passes after the docstring edits (proves no behaviour regression).
- [ ] `python3 -c "import ast; ast.parse(open('scripts/validate_skill.py').read())"`
      succeeds — the edited Python file is syntactically valid.
- [ ] Every top-level `def` in `scripts/validate_skill.py` has a docstring — verify with
      `python3 -c "import ast,sys; t=ast.parse(open('scripts/validate_skill.py').read()); missing=[n.name for n in t.body if isinstance(n,ast.FunctionDef) and not ast.get_docstring(n)]; print(missing); sys.exit(1 if missing else 0)"`.
- [ ] `README.md` names all five detection dimensions and all five rating bands —
      `grep -F` each of: "Factual red flag", "Bias & framing", "Logical fallacy",
      "Clickbait / hype", "Narrative manipulation", "Credible", "Mostly Credible",
      "Mixed", "Low Credibility", "Not Credible".
- [ ] `README.md` mentions verbatim quote evidence and prompt-injection / untrusted-data
      handling — `grep -iE 'verbatim|quote'` and `grep -iE 'untrusted|prompt[- ]injection'`.
- [ ] `README.md` contains a sample-output block using the `## Verdict` / `## Findings` /
      `## Rationale` template — `grep -F '## Verdict'` and `grep -F '## Findings'`.
- [ ] `CHANGELOG.md` exists and references each issue #11 through #16 — `grep -E '#1[1-6]'`.

## Acceptance criteria

- [ ] README.md describes the fake-news-detector skill, listing the five detection
      dimensions, the five credibility rating bands, verbatim-quote evidence, the
      user-friendly summary layer, and prompt-injection / untrusted-data hardening.
- [ ] README.md includes a usage example with a sample output block matching the
      output-format template.
- [ ] All feature names and rating-band labels in README.md match the skill reference
      files verbatim (no invented or renamed dimensions/bands).
- [ ] Every top-level function in `scripts/validate_skill.py` has a docstring; the
      module docstring is present; no executable logic or signatures changed.
- [ ] CHANGELOG.md exists in Keep-a-Changelog format with an Added section covering the
      work from PRs/issues #11–#16, referencing the issue numbers.
- [ ] `bash scripts/build.sh && bash scripts/test.sh` passes (skill validation green).
