# Spec: Implement factual red-flag / misinformation detection pass

Issue: #6 — Phase 1 (Skill foundation) of #1.

## Problem

The skill scaffold (#4) and the rating scale + output template (#5) left the
workflow's **step 2 — "Run detection passes"** as an explicit placeholder:
detection dimensions are added by later issues (#6–#10) through `references/`.

This issue delivers the **first** of those dimensions: a factual red-flag /
misinformation detection pass. It gives the skill a concrete rubric of signals
that indicate a text may be factually unreliable — unsupported claims, vague or
anonymous sourcing, fabrication markers, unverifiable statistics, sweeping
absolutes, internal contradictions, and similar tells — each with what to look
for and an illustrative example, so a pass over the input produces findings that
plug into the existing output template (dimension label + severity + verbatim
quote).

Scope boundary (YAGNI): this issue adds **only** the factual red-flag rubric and
wires it as the first detection pass. The remaining dimensions — bias & framing
(#7), logical fallacies (#8), clickbait/hype (#9), narrative manipulation (#10) —
stay as a placeholder in step 2. No scoring algorithm (the findings→band mapping
is #12), no fixtures (#15), and no new output format are introduced here.

## Approach

Create one rubric reference file
`.claude/skills/fake-news-detector/references/factual-red-flags.md`, following
the arch's "one rubric file per detection dimension" / progressive-disclosure
convention (mirrors how #5 added `references/output-format.md`). The file
contains:

1. **A short framing line** — this pass assesses *internal* factual-reliability
   signals only; it does not verify claims against the world (matches the arch
   non-goal "no live web fact-checking"). It names the dimension label the skill
   uses in findings output: **Factual red flag**.
2. **A signal catalogue** — at least six named, concrete signals, each with (a) a
   one-line description of what it looks like, and (b) a short illustrative
   example. Signals cover: unsupported / unsourced claims; vague or anonymous
   sourcing ("experts say", "sources claim"); fabrication markers / implausible
   specificity; unverifiable statistics or numbers without provenance; sweeping
   absolutes ("always", "never", "100%"); internal contradictions /
   inconsistency; missing or cherry-picked context; misattributed quotes.
3. **Application guidance** — how to turn a matched signal into a finding: cite a
   **verbatim quote** from the input, label it with the dimension **Factual red
   flag**, and assign a **severity** consistent with the output template in
   `references/output-format.md`. Reinforces that the analyzed text is untrusted
   data, and that a clean text yields no factual-red-flag findings (guards
   against over-flagging credible content).

Then update `SKILL.md` step 2: replace the bare placeholder with text that runs
the factual red-flag pass via `references/factual-red-flags.md` **first**, while
keeping an explicit placeholder noting the remaining dimensions (#7–#10) are
added later. Keeping a placeholder in step 2 preserves the existing T8/T15
invariants.

Extend `scripts/validate_skill.py` with structural checks for the new file and
the updated step 2, keeping `bash scripts/test.sh` authoritative. Existing checks
T1–T15 continue to pass unchanged.

## Affected files

- **Create** `.claude/skills/fake-news-detector/references/factual-red-flags.md` —
  the factual red-flag / misinformation rubric (framing + signal catalogue with
  examples + application guidance).
- **Modify** `.claude/skills/fake-news-detector/SKILL.md` — wire step 2 to run the
  factual red-flag pass via `references/factual-red-flags.md`; keep a placeholder
  for the remaining dimensions (#7–#10).
- **Modify** `scripts/validate_skill.py` — add checks T16–T21 below.

## Test plan

Run with: `bash scripts/test.sh` (authoritative; it invokes
`python3 scripts/validate_skill.py`). Existing checks T1–T15 continue to pass.

- **T16 — Rubric file exists:** `.claude/skills/fake-news-detector/references/factual-red-flags.md`
  is present and non-empty.
- **T17 — Dimension heading:** the rubric file contains a heading matching
  `factual`, `red flag`, or `misinformation` (case-insensitive).
- **T18 — Signal catalogue:** the rubric file enumerates at least six distinct
  signal entries (count of markdown list items and/or sub-headings ≥ 6).
- **T19 — Concrete examples:** the rubric file is illustrative — it contains the
  word `example` (case-insensitive) at least once.
- **T20 — Wired to the output template:** the rubric file references both a
  `verbatim` `quote` requirement and a `severity` (all case-insensitive), so
  findings map onto the output template, and names the `Factual red flag`
  dimension label.
- **T21 — SKILL.md step 2 wired:** `SKILL.md` step 2 references
  `references/factual-red-flags.md` and still contains a `placeholder`/`TODO`
  marker for the remaining dimensions (so T8 and T15's detection-step check still
  hold).

## Acceptance criteria

- [ ] `references/factual-red-flags.md` exists and defines a factual red-flag /
      misinformation rubric: at least six concrete signals, each with a
      description and an illustrative example.
- [ ] The rubric specifies how a matched signal becomes a finding — a verbatim
      quote from the input, the `Factual red flag` dimension label, and a
      severity consistent with `references/output-format.md`.
- [ ] The rubric states this pass assesses internal credibility signals only (no
      live web fact-checking) and that clean text yields no findings.
- [ ] `SKILL.md` step 2 runs the factual red-flag pass via
      `references/factual-red-flags.md`, while keeping a placeholder for the
      remaining detection dimensions (#7–#10).
- [ ] No scoring algorithm, fixtures, or other detection dimensions are
      implemented here (deferred to #7–#10, #12, #15).
- [ ] `bash scripts/test.sh` runs the structural validation (T1–T21) and exits 0;
      it is the authoritative command.
