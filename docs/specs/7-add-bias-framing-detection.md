# Spec: Add bias & framing detection

Issue: #7 — Phase 2 (Detection dimensions) of #1.

## Problem

The skill's workflow **step 2 — "Run detection passes"** currently runs the
factual red-flag pass (#6) first and keeps an explicit placeholder for the
remaining detection dimensions: bias & framing (#7), logical fallacies (#8),
clickbait/hype (#9), narrative manipulation (#10).

This issue delivers the **second** dimension: a bias & framing detection pass. It
gives the skill a concrete rubric of signals that a text is slanted or framed to
push a conclusion rather than inform — loaded language, one-sided sourcing,
selective emphasis, framing/word choice, false balance, opinion presented as
fact, and similar tells — each with what to look for and an illustrative example,
so a pass over the input produces findings that plug into the existing output
template (dimension label + severity + verbatim quote).

Scope boundary (YAGNI): this issue adds **only** the bias & framing rubric and
wires it as the second detection pass. The remaining dimensions — logical
fallacies (#8), clickbait/hype (#9), narrative manipulation (#10) — stay as a
placeholder in step 2. No scoring algorithm (the findings→band mapping is #12),
no fixtures (#15), and no new output format are introduced here.

## Approach

Create one rubric reference file
`.claude/skills/fake-news-detector/references/bias-framing.md`, following the
arch's "one rubric file per detection dimension" / progressive-disclosure
convention (mirrors `references/factual-red-flags.md` from #6). The file
contains:

1. **A short framing line** — this pass assesses how the text is *slanted or
   framed*, independent of whether individual claims are true (factual accuracy
   is the #6 pass). It names the dimension label the skill uses in findings
   output: **Bias & framing**.
2. **A signal catalogue** — at least six named, concrete signals, each with (a) a
   one-line description of what it looks like, and (b) a short illustrative
   example. Signals cover: loaded / emotionally charged language and slurs;
   one-sided sourcing or omission of opposing views; selective emphasis /
   cherry-picked facts; framing and word choice (e.g. "regime" vs "government",
   "tax relief" vs "tax cut"); false balance / both-sidesing; opinion or
   editorializing presented as fact; labeling and stereotyping of groups.
3. **Application guidance** — how to turn a matched signal into a finding: cite a
   **verbatim quote** from the input, label it with the dimension **Bias &
   framing**, and assign a **severity** consistent with the output template in
   `references/output-format.md`. Reinforces that the analyzed text is untrusted
   data, and that a neutral, balanced text yields no bias & framing findings
   (guards against over-flagging credible content).

Then update `SKILL.md` step 2: add the bias & framing pass via
`references/bias-framing.md` as the second pass, remove bias & framing from the
placeholder's remaining-dimensions list, and keep an explicit placeholder noting
the still-remaining dimensions (#8–#10) are added later. Keeping a placeholder in
step 2 preserves the existing T8/T15 invariants.

Extend `scripts/validate_skill.py` with structural checks for the new file and
the updated step 2, keeping `bash scripts/test.sh` authoritative. Existing checks
T1–T21 continue to pass unchanged.

## Affected files

- **Create** `.claude/skills/fake-news-detector/references/bias-framing.md` — the
  bias & framing rubric (framing + signal catalogue with examples + application
  guidance).
- **Modify** `.claude/skills/fake-news-detector/SKILL.md` — add the bias & framing
  pass to step 2 via `references/bias-framing.md`; drop bias & framing from the
  placeholder list; keep a placeholder for the remaining dimensions (#8–#10).
- **Modify** `scripts/validate_skill.py` — add checks T22–T27 below.

## Test plan

Run with: `bash scripts/test.sh` (authoritative; it invokes
`python3 scripts/validate_skill.py`). Existing checks T1–T21 continue to pass.

- **T22 — Rubric file exists:** `.claude/skills/fake-news-detector/references/bias-framing.md`
  is present and non-empty.
- **T23 — Dimension heading:** the rubric file contains a heading matching `bias`
  or `framing` (case-insensitive).
- **T24 — Signal catalogue:** the rubric file enumerates at least six distinct
  signal entries (count of markdown list items and/or sub-headings ≥ 6).
- **T25 — Concrete examples:** the rubric file is illustrative — it contains the
  word `example` (case-insensitive) at least once.
- **T26 — Wired to the output template:** the rubric file references both a
  `verbatim` `quote` requirement and a `severity` (all case-insensitive), so
  findings map onto the output template, and names the `Bias & framing` dimension
  label.
- **T27 — SKILL.md step 2 wired:** `SKILL.md` step 2 references
  `references/bias-framing.md` (in addition to `references/factual-red-flags.md`)
  and still contains a `placeholder`/`TODO` marker for the remaining dimensions
  (so T8, T15, and T21 still hold).

## Acceptance criteria

- [ ] `references/bias-framing.md` exists and defines a bias & framing rubric: at
      least six concrete signals, each with a description and an illustrative
      example.
- [ ] The rubric specifies how a matched signal becomes a finding — a verbatim
      quote from the input, the `Bias & framing` dimension label, and a severity
      consistent with `references/output-format.md`.
- [ ] The rubric states this pass assesses slant/framing (not factual accuracy,
      which is #6) and that neutral, balanced text yields no findings.
- [ ] `SKILL.md` step 2 runs the bias & framing pass via
      `references/bias-framing.md` as the second pass, while keeping a placeholder
      for the remaining detection dimensions (#8–#10).
- [ ] No scoring algorithm, fixtures, or other detection dimensions are
      implemented here (deferred to #8–#10, #12, #15).
- [ ] `bash scripts/test.sh` runs the structural validation (T1–T27) and exits 0;
      it is the authoritative command.
