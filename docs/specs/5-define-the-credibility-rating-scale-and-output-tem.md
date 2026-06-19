# Spec: Define the credibility rating scale and output template

Issue: #5 — Phase 1 (Skill foundation) of #1.

## Problem

The detector skill scaffold (#4) left two explicit placeholders in `SKILL.md`:
step 3 "score & aggregate" (the rating scale and scoring rules) and step 4
"render verdict" (the final output template). This issue fills those two
placeholders by defining:

- **A fixed credibility rating scale** — a small banded ordinal set, each band
  with a one-line definition, so verdicts are deterministic and repeatable
  rather than ad-hoc (per the arch "fixed rubric + banded rating scale" choice).
- **An output template** — the exact rendered layout: a short user-friendly
  verdict on top, then a detailed findings list where every finding cites a
  verbatim quote, then a concise rationale.

Scope boundary (YAGNI): this issue defines *what the bands are* and *what the
output looks like*. It does **not** implement the scoring algorithm that maps
findings → a band (that is #12, "overall credibility scoring and rationale
synthesis"), nor any detection dimension (#6–#10), nor the summary layer polish
(#13). The detection-dimensions placeholder in the workflow stays untouched.

## Approach

Create one reference file `.claude/skills/fake-news-detector/references/output-format.md`
that holds both deliverables, loaded progressively when the skill renders a verdict
(matching the arch's `references/` progressive-disclosure convention). It contains
two sections:

1. **Credibility rating scale** — five named bands, highest to lowest, each with a
   short definition of when it applies:
   - **Credible** — no material red flags; claims are sourced/verifiable in-text and framing is fair.
   - **Mostly Credible** — minor issues (mild framing, a weak source) that do not undermine the core.
   - **Mixed** — a blend of substantiated and unsupported/misleading elements; read with caution.
   - **Low Credibility** — multiple significant red flags (unsupported claims, heavy bias, fallacies).
   - **Not Credible** — pervasive misinformation signals, fabrication markers, or manipulation throughout.

2. **Output template** — a fixed layout with three parts: (a) a **Verdict** block —
   the band plus a one-sentence plain-language takeaway; (b) a **Findings** list —
   zero or more entries, each with a dimension label, a severity, a **verbatim quote**
   from the input, and a one-line explanation; an explicit "No significant issues
   found" line is used when the findings list is empty (guards against over-flagging
   credible content); (c) a **Rationale** — a concise paragraph tying the findings to
   the chosen band. The template is given as a literal markdown skeleton so renders
   are consistent.

Then update `SKILL.md`: replace the step-3 and step-4 placeholders so they reference
`references/output-format.md` (score/aggregate against the rating scale; render using
the output template). Leave the step-2 detection-dimensions placeholder in place.

Extend `scripts/validate_skill.py` with structural checks for the new file and for the
updated `SKILL.md`, keeping `bash scripts/test.sh` authoritative.

## Affected files

- **Create** `.claude/skills/fake-news-detector/references/output-format.md` — the
  rating scale (5 bands + definitions) and the output template skeleton.
- **Modify** `.claude/skills/fake-news-detector/SKILL.md` — replace the score/aggregate
  and render-verdict placeholders with references to `references/output-format.md`;
  keep the detection-dimensions placeholder.
- **Modify** `scripts/validate_skill.py` — add the checks below (T10–T15).

## Test plan

Run with: `bash scripts/test.sh` (authoritative; it invokes `python3 scripts/validate_skill.py`).
Existing checks T1–T8 from #4 continue to pass unchanged.

- **T10 — Reference file exists:** `.claude/skills/fake-news-detector/references/output-format.md` is present and non-empty.
- **T11 — Rating-scale section:** the reference file contains a heading matching `rating` or `scale` (case-insensitive).
- **T12 — All five bands defined:** the reference file contains each band name — `Credible`, `Mostly Credible`, `Mixed`, `Low Credibility`, `Not Credible` (case-insensitive) — and each band line also carries a definition (text after the name, not just the bare label).
- **T13 — Output-template sections:** the reference file contains the three required section markers — a verdict marker (`Verdict`), a findings marker (`Findings`), and a rationale marker (`Rationale`), case-insensitive.
- **T14 — Verbatim-quote requirement:** the findings portion of the template requires a quoted excerpt — the file contains both `verbatim` and `quote` (case-insensitive), and an empty-findings line (matches `no significant issues` / `no issues found`, case-insensitive).
- **T15 — SKILL.md wired up:** `SKILL.md` references `references/output-format.md`, the score/aggregate and render-verdict steps no longer contain `placeholder`/`TODO`, and the detection-dimensions step still does (so T8 still holds).

## Acceptance criteria

- [ ] `references/output-format.md` exists and defines a banded credibility rating scale of five bands — `Credible`, `Mostly Credible`, `Mixed`, `Low Credibility`, `Not Credible` — each with a one-line definition.
- [ ] The same file specifies an output template with a Verdict block (band + one-line takeaway), a Findings list, and a Rationale.
- [ ] The findings template requires each finding to cite a verbatim quote from the input, and specifies an explicit "no significant issues found" line for the empty case.
- [ ] `SKILL.md`'s score/aggregate and render-verdict steps reference `references/output-format.md` instead of placeholders, while the detection-dimensions step remains a placeholder for later issues.
- [ ] No scoring algorithm or detection logic is implemented here (deferred to #12 and #6–#10).
- [ ] `bash scripts/test.sh` runs the structural validation (T1–T15) and exits 0; it is the authoritative command.
