# Spec: Add user-friendly summary layer above the detailed breakdown

Issue: #13 — Phase 3 (Verdict synthesis & output) of #1, the final piece.

## Problem

The arch (`docs/arch/build-a-fake-news-misinformation-detector-skill.md`) calls
for the rendered output to "provide both a user-friendly summary and a detailed
breakdown" — "a short user-friendly verdict on top, then the detailed findings
list and rationale" (data-flow step 5).

The pieces below the summary already exist: the five-band rating scale and
document layout (#5, `references/output-format.md`), the per-finding entry
format (#11, `references/findings-format.md`), and the scoring/rationale rules
(#12, `references/scoring.md`). The current `## Verdict` section is thin — just
`**Rating:**` plus a single `<One-sentence plain-language takeaway.>` line — and
there is no rule governing what that top layer must contain or how it must read.
Today the top of the output and the detailed breakdown are not clearly
separated, and nothing requires the summary to be readable on its own by a
non-expert.

This issue defines the **user-friendly summary layer**: the at-a-glance block at
the top of the output that a lay reader can stop at and still understand the
verdict, written in plain language and derived strictly from the rating and the
already-listed findings.

Scope boundary (YAGNI): this issue defines *only* the top summary layer and
wires it into the render step. It does **not** change any detection pass
(#6–#10), the per-finding format (#11), the banding/rationale rules (#12), or
the five band definitions (#5) — all consumed as-is. No numeric scores,
confidence levels, badges/emoji, or per-dimension sub-summaries are added. No
code runtime; this is rubric markdown plus validator checks. Fixtures remain
#15.

## Approach

Create one reference file
`.claude/skills/fake-news-detector/references/summary-format.md`, following the
existing progressive-disclosure `references/` convention. It is the single
source of truth for the **top summary layer**, while `output-format.md` stays
the source of truth for the band *definitions* and overall document layout,
`findings-format.md` for per-finding entries, and `scoring.md` for
aggregation/rationale. It contains:

1. **Position** — the summary is the first section of the output, above the
   detailed breakdown (the `## Findings` and `## Rationale` sections). It is
   self-contained: a reader could stop after the summary and have an accurate
   bottom line.
2. **Contents** — the chosen credibility rating band (verbatim from
   `references/output-format.md`); a one-sentence plain-language takeaway; and a
   short bottom-line naming, in plain terms, the main reason(s) the verdict
   landed where it did — led by the highest-severity findings — or brief, honest
   reassurance when the result is `Credible` with no findings.
3. **Plain-language discipline** — written for a non-expert: no dimension labels
   (e.g. "Narrative manipulation"), no severity vocabulary (`High`/`Medium`/
   `Low`), and no jargon; those belong in the detailed breakdown below.
4. **Consistency discipline** — derived solely from the selected rating and the
   already-listed findings; it introduces no new claims, quotes, or findings and
   stays consistent with the band and with the `## Rationale`. The summary
   summarizes; it never adds analysis.
5. **A worked example** — a small case (e.g. a `Low Credibility` result) showing
   the rendered summary block, reinforcing that the analyzed text is untrusted
   data.

Then **wire it in**:

- `references/output-format.md` — make the top `## Verdict` section the
  user-friendly summary: keep `**Rating:**`, keep the one-sentence plain-language
  takeaway, add the plain-language bottom-line line, and add a one-line pointer
  to `references/summary-format.md`. The `Verdict`/`Findings`/`Rationale`
  markers, band definitions, and empty-state line are unchanged (additive only).
- `SKILL.md` — update **step 4** so it renders the top summary per
  `references/summary-format.md` in addition to the existing references to
  `references/output-format.md` and `references/findings-format.md`. Steps 1–3
  are unchanged.

Extend `scripts/validate_skill.py` with structural checks T59–T64 for the new
file and the updated step-4 wiring. All existing checks (T1–T58) continue to
pass unchanged — the change is additive (`output-format.md` gains one line plus
a pointer; step 4 gains a third reference). `bash scripts/test.sh` stays
authoritative.

## Affected files

- **Create** `.claude/skills/fake-news-detector/references/summary-format.md` —
  the top summary layer: position, contents, plain-language discipline,
  consistency discipline, and a worked example.
- **Modify** `.claude/skills/fake-news-detector/references/output-format.md` —
  the `## Verdict` section becomes the user-friendly summary (adds the
  plain-language bottom-line line) and points to `references/summary-format.md`
  (additive only).
- **Modify** `.claude/skills/fake-news-detector/SKILL.md` — step 4 renders the
  summary per `references/summary-format.md` in addition to
  `references/output-format.md` and `references/findings-format.md`.
- **Modify** `scripts/validate_skill.py` — add checks T59–T64.

## Test plan

Run with: `bash scripts/test.sh` (authoritative; it invokes
`python3 scripts/validate_skill.py`). Existing checks T1–T58 continue to pass
unchanged.

- **T59 — Reference file exists:**
  `.claude/skills/fake-news-detector/references/summary-format.md` is present and
  non-empty.
- **T60 — Summary heading:** the file contains a heading matching `summary`,
  `verdict`, or `takeaway` (case-insensitive).
- **T61 — Position above breakdown:** the file states the summary sits at the
  top, above the detailed breakdown — it references both `Findings` and
  `Rationale` (or "detailed breakdown") and a positioning word (`top`, `above`,
  or `first`).
- **T62 — Plain-language discipline:** the file requires plain, non-expert
  language — it contains at least one of `plain`, `non-expert`, `jargon`, or
  `lay` (case-insensitive).
- **T63 — Consistency discipline + example:** the file states the
  no-new-claims/consistency rule — at least one of `consistent`, `no new`, or
  `not introduce` — and includes a worked `example` (case-insensitive).
- **T64 — SKILL.md & output-format wired up:** step 4 references
  `references/summary-format.md`, `references/output-format.md`, and
  `references/findings-format.md`, with no `placeholder`/`TODO`; and
  `output-format.md` points to `references/summary-format.md`.
- **Regression:** existing T1–T58 continue to pass unchanged.

## Acceptance criteria

- [ ] `references/summary-format.md` exists and defines the top, self-contained
      user-friendly summary layer that sits above the detailed breakdown
      (`## Findings` and `## Rationale`).
- [ ] It specifies the summary contents: the selected rating band, a one-sentence
      plain-language takeaway, and a plain-language bottom-line of the main
      reason(s) (or honest reassurance for a clean `Credible` result).
- [ ] It requires plain, non-expert language (no dimension labels, no
      `High`/`Medium`/`Low` severity vocabulary, no jargon) and a consistency
      discipline (derived only from the rating and listed findings; no new
      claims, quotes, or findings), plus a worked example.
- [ ] `SKILL.md` step 4 renders the summary per `references/summary-format.md` in
      addition to `references/output-format.md` and `references/findings-format.md`,
      and `output-format.md`'s `## Verdict` section is the user-friendly summary
      and points to `references/summary-format.md`.
- [ ] No detection pass, per-finding format, scoring/rationale rules, band
      definitions, numeric scores/confidence/badges, or fixtures are added or
      changed here (owned by #5–#12 and #15).
- [ ] `bash scripts/test.sh` runs the structural validation (including new
      T59–T64) and exits 0; it is the authoritative command.
