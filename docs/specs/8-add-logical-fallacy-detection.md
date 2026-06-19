# Spec: Add logical-fallacy detection

Issue: #8 — Phase 2 (Detection dimensions) of #1.

## Problem

The skill's workflow **step 2 — "Run detection passes"** currently runs the
factual red-flag pass (#6) and the bias & framing pass (#7), and keeps an
explicit placeholder for the remaining detection dimensions: logical fallacies
(#8), clickbait/hype (#9), and narrative manipulation (#10).

This issue delivers the **third** dimension: a logical-fallacy detection pass. It
gives the skill a concrete rubric of common reasoning fallacies — ad hominem,
straw man, false dilemma, appeal to fear/emotion, appeal to (improper) authority,
hasty generalization, post hoc / false cause, slippery slope, and similar tells —
each with what to look for and an illustrative example, so a pass over the input
produces findings that plug into the existing output template (dimension label +
severity + verbatim quote).

Scope boundary (YAGNI): this issue adds **only** the logical-fallacy rubric and
wires it as the third detection pass. The remaining dimensions — clickbait/hype
(#9) and narrative manipulation (#10) — stay as a placeholder in step 2. No
scoring algorithm (the findings→band mapping is #12), no fixtures (#15), and no
new output format are introduced here.

## Approach

Create one rubric reference file
`.claude/skills/fake-news-detector/references/logical-fallacies.md`, following the
arch's "one rubric file per detection dimension" / progressive-disclosure
convention (mirrors `references/factual-red-flags.md` from #6 and
`references/bias-framing.md` from #7). The file contains:

1. **A short framing line** — this pass assesses *flawed reasoning / argument
   structure*, independent of whether the underlying claims are factually true
   (factual accuracy is the #6 pass) or how the text is slanted (#7 pass). It
   names the dimension label the skill uses in findings output: **Logical
   fallacy**.
2. **A signal catalogue** — at least six named, concrete fallacies, each with (a)
   a one-line description of what it looks like, and (b) a short illustrative
   example. Cover at minimum: ad hominem; straw man; false dilemma / either-or;
   appeal to fear or emotion; appeal to improper authority / popularity; hasty
   generalization; post hoc / false cause (correlation ≠ causation); slippery
   slope.
3. **Application guidance** — how to turn a matched fallacy into a finding: cite a
   **verbatim quote** from the input, label it with the dimension **Logical
   fallacy**, and assign a **severity** consistent with the output template in
   `references/output-format.md`. Reinforces that the analyzed text is untrusted
   data, and that a soundly-argued text yields no logical-fallacy findings (guards
   against over-flagging credible content).

Then update `SKILL.md` step 2: add the logical-fallacy pass via
`references/logical-fallacies.md` as the third pass, remove logical fallacies from
the placeholder's remaining-dimensions list, and keep an explicit placeholder
noting the still-remaining dimensions (#9–#10) are added later. Keeping a
placeholder in step 2 preserves the existing T8/T15 invariants.

Extend `scripts/validate_skill.py` with structural checks for the new file and the
updated step 2, keeping `bash scripts/test.sh` authoritative. Existing checks
T1–T27 continue to pass unchanged.

## Affected files

- **Create** `.claude/skills/fake-news-detector/references/logical-fallacies.md` —
  the logical-fallacy rubric (framing + fallacy catalogue with examples +
  application guidance).
- **Modify** `.claude/skills/fake-news-detector/SKILL.md` — add the logical-fallacy
  pass to step 2 via `references/logical-fallacies.md`; drop logical fallacies from
  the placeholder list; keep a placeholder for the remaining dimensions (#9–#10).
- **Modify** `scripts/validate_skill.py` — add checks T28–T33 below.

## Test plan

Run with: `bash scripts/test.sh` (authoritative; it invokes
`python3 scripts/validate_skill.py`). Existing checks T1–T27 continue to pass.

- **T28 — Rubric file exists:** `.claude/skills/fake-news-detector/references/logical-fallacies.md`
  is present and non-empty.
- **T29 — Dimension heading:** the rubric file contains a heading matching
  `logical` or `fallac` (case-insensitive).
- **T30 — Fallacy catalogue:** the rubric file enumerates at least six distinct
  signal entries (count of markdown list items and/or sub-headings ≥ 6).
- **T31 — Concrete examples:** the rubric file is illustrative — it contains the
  word `example` (case-insensitive) at least once.
- **T32 — Wired to the output template:** the rubric file references both a
  `verbatim` `quote` requirement and a `severity` (all case-insensitive), so
  findings map onto the output template, and names the `Logical fallacy` dimension
  label.
- **T33 — SKILL.md step 2 wired:** `SKILL.md` step 2 references
  `references/logical-fallacies.md` (in addition to
  `references/factual-red-flags.md` and `references/bias-framing.md`) and still
  contains a `placeholder`/`TODO` marker for the remaining dimensions (so T8, T15,
  T21, and T27 still hold).

## Acceptance criteria

- [ ] `references/logical-fallacies.md` exists and defines a logical-fallacy
      rubric: at least six concrete fallacies, each with a description and an
      illustrative example.
- [ ] The rubric specifies how a matched fallacy becomes a finding — a verbatim
      quote from the input, the `Logical fallacy` dimension label, and a severity
      consistent with `references/output-format.md`.
- [ ] The rubric states this pass assesses reasoning/argument structure (not
      factual accuracy, which is #6, nor slant/framing, which is #7) and that a
      soundly-argued text yields no findings.
- [ ] `SKILL.md` step 2 runs the logical-fallacy pass via
      `references/logical-fallacies.md` as the third pass, while keeping a
      placeholder for the remaining detection dimensions (#9–#10).
- [ ] No scoring algorithm, fixtures, or other detection dimensions are
      implemented here (deferred to #9–#10, #12, #15).
- [ ] `bash scripts/test.sh` runs the structural validation (T1–T33) and exits 0;
      it is the authoritative command.
