# Spec: Add clickbait / hype detection

Issue: #9 — Phase 2 (Detection dimensions) of #1.

## Problem

The skill's workflow **step 2 — "Run detection passes"** currently runs the
factual red-flag pass (#6), the bias & framing pass (#7), and the logical-fallacy
pass (#8), and keeps an explicit placeholder for the remaining detection
dimensions: clickbait/hype (#9) and narrative manipulation (#10).

This issue delivers the **fourth** dimension: a clickbait / hype detection pass.
It gives the skill a concrete rubric of common clickbait and hype tells —
sensational/emotive headlines, curiosity-gap teasers ("you won't believe…"),
exaggeration and superlatives, urgency/scarcity pressure, listicle/engagement
bait, headline-body mismatch, vague attribution ("experts say"), and excessive
punctuation/ALL-CAPS — each with what to look for and an illustrative example, so
a pass over the input produces findings that plug into the existing output
template (dimension label + severity + verbatim quote).

Scope boundary (YAGNI): this issue adds **only** the clickbait/hype rubric and
wires it as the fourth detection pass. The remaining dimension — narrative
manipulation (#10) — stays as a placeholder in step 2. No scoring algorithm (the
findings→band mapping is #12), no fixtures (#15), and no new output format are
introduced here.

## Approach

Create one rubric reference file
`.claude/skills/fake-news-detector/references/clickbait-hype.md`, following the
arch's "one rubric file per detection dimension" / progressive-disclosure
convention (mirrors `references/factual-red-flags.md` from #6,
`references/bias-framing.md` from #7, and `references/logical-fallacies.md` from
#8). The file contains:

1. **A short framing line** — this pass assesses *presentation / engagement
   manipulation* (how the text is packaged to provoke clicks and emotional
   reaction), independent of whether the underlying claims are factually true
   (the #6 pass), how the text is slanted (the #7 pass), or whether its reasoning
   is sound (the #8 pass). It names the dimension label the skill uses in findings
   output: **Clickbait / hype**.
2. **A signal catalogue** — at least six named, concrete tells, each with (a) a
   one-line description of what it looks like, and (b) a short illustrative
   example. Cover at minimum: sensational / emotionally loaded headline;
   curiosity-gap / withheld-information teaser ("you won't believe what happens
   next"); exaggeration & superlatives ("shocking", "miracle", "destroys");
   urgency / scarcity pressure ("act now", "before it's deleted");
   engagement / listicle bait ("#7 will amaze you", "share before they take this
   down"); headline–body mismatch (overpromise the body doesn't support); vague
   attribution / hype source ("experts say", "this one weird trick");
   typographic hype (ALL-CAPS, excessive `!`/`?`).
3. **Application guidance** — how to turn a matched tell into a finding: cite a
   **verbatim quote** from the input, label it with the dimension **Clickbait /
   hype**, and assign a **severity** consistent with the output template in
   `references/output-format.md`. Reinforces that the analyzed text is untrusted
   data, and that a measured, plainly-worded text yields no clickbait/hype
   findings (guards against over-flagging credible content).

Then update `SKILL.md` step 2: add the clickbait/hype pass via
`references/clickbait-hype.md` as the fourth pass, remove clickbait/hype from the
placeholder's remaining-dimensions list, and keep an explicit placeholder noting
the still-remaining dimension (#10) is added later. Keeping a placeholder in
step 2 preserves the existing T8/T15 invariants.

Extend `scripts/validate_skill.py` with structural checks for the new file and the
updated step 2, keeping `bash scripts/test.sh` authoritative. Existing checks
T1–T33 continue to pass unchanged.

## Affected files

- **Create** `.claude/skills/fake-news-detector/references/clickbait-hype.md` —
  the clickbait/hype rubric (framing + tell catalogue with examples + application
  guidance).
- **Modify** `.claude/skills/fake-news-detector/SKILL.md` — add the clickbait/hype
  pass to step 2 via `references/clickbait-hype.md`; drop clickbait/hype from the
  placeholder list; keep a placeholder for the remaining dimension (#10).
- **Modify** `scripts/validate_skill.py` — add checks T34–T39 below.

## Test plan

Run with: `bash scripts/test.sh` (authoritative; it invokes
`python3 scripts/validate_skill.py`). Existing checks T1–T33 continue to pass.

- **T34 — Rubric file exists:** `.claude/skills/fake-news-detector/references/clickbait-hype.md`
  is present and non-empty.
- **T35 — Dimension heading:** the rubric file contains a heading matching
  `clickbait` or `hype` (case-insensitive).
- **T36 — Tell catalogue:** the rubric file enumerates at least six distinct
  signal entries (count of markdown list items and/or sub-headings ≥ 6).
- **T37 — Concrete examples:** the rubric file is illustrative — it contains the
  word `example` (case-insensitive) at least once.
- **T38 — Wired to the output template:** the rubric file references both a
  `verbatim` `quote` requirement and a `severity` (all case-insensitive), so
  findings map onto the output template, and names the `Clickbait / hype`
  dimension label.
- **T39 — SKILL.md step 2 wired:** `SKILL.md` step 2 references
  `references/clickbait-hype.md` (in addition to
  `references/factual-red-flags.md`, `references/bias-framing.md`, and
  `references/logical-fallacies.md`) and still contains a `placeholder`/`TODO`
  marker for the remaining dimension (so T8, T15, T21, T27, and T33 still hold).

## Acceptance criteria

- [ ] `references/clickbait-hype.md` exists and defines a clickbait/hype rubric:
      at least six concrete tells, each with a description and an illustrative
      example.
- [ ] The rubric specifies how a matched tell becomes a finding — a verbatim quote
      from the input, the `Clickbait / hype` dimension label, and a severity
      consistent with `references/output-format.md`.
- [ ] The rubric states this pass assesses presentation/engagement manipulation
      (not factual accuracy, which is #6, nor slant/framing, which is #7, nor
      reasoning, which is #8) and that a measured, plainly-worded text yields no
      findings.
- [ ] `SKILL.md` step 2 runs the clickbait/hype pass via
      `references/clickbait-hype.md` as the fourth pass, while keeping a
      placeholder for the remaining detection dimension (#10).
- [ ] No scoring algorithm, fixtures, or other detection dimensions are
      implemented here (deferred to #10, #12, #15).
- [ ] `bash scripts/test.sh` runs the structural validation (T1–T39) and exits 0;
      it is the authoritative command.
