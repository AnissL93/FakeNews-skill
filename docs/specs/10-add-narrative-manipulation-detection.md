# Spec: Add narrative-manipulation detection

Issue: #10 — Phase 2 (Detection dimensions) of #1.

## Problem

The skill's workflow **step 2 — "Run detection passes"** currently runs four
passes — factual red flags (#6), bias & framing (#7), logical fallacies (#8), and
clickbait / hype (#9) — and keeps an explicit placeholder for the one remaining
detection dimension: narrative manipulation (#10).

This issue delivers that **fifth and final** dimension: a narrative-manipulation
detection pass. It gives the skill a concrete rubric of common narrative-level
manipulation tells — cherry-picking / selective evidence, missing context /
decontextualization, anecdote-as-proof, insinuation / guilt by association,
conspiratorial "connect the dots" framing, us-vs-them / scapegoating,
misleading sequencing or chronology, and pre-emptive discrediting of dissent —
each with what to look for and an illustrative example, so a pass over the input
produces findings that plug into the existing output template (dimension label +
severity + verbatim quote).

Because this is the **last** detection dimension, it also closes out step 2:
after this issue there are no further dimensions to add, so the
"remaining detection dimensions" placeholder in step 2 is removed. Scope boundary
(YAGNI): this issue adds **only** the narrative-manipulation rubric, wires it as
the fifth pass, and retires the now-obsolete detection placeholder. No scoring
algorithm (the findings→band mapping is #12), no findings-format work (#11), no
fixtures (#15), and no new output format are introduced here.

## Approach

Create one rubric reference file
`.claude/skills/fake-news-detector/references/narrative-manipulation.md`, following
the arch's "one rubric file per detection dimension" / progressive-disclosure
convention (mirrors `references/factual-red-flags.md` from #6,
`references/bias-framing.md` from #7, `references/logical-fallacies.md` from #8,
and `references/clickbait-hype.md` from #9). The file contains:

1. **A short framing line** — this pass assesses *how the overall story is
   constructed, selected, and sequenced to steer the reader's interpretation*:
   manipulation operating at the narrative/structural level rather than on
   individual statements. It is independent of factual accuracy (the #6 pass),
   word-level slant / framing (the #7 pass), reasoning structure (the #8 pass),
   and presentation / engagement packaging (the #9 pass). To keep the boundary
   with bias & framing clear, note that #7 targets phrasing and word choice while
   this pass targets selection, omission, insinuation, and ordering of the
   narrative as a whole. It names the dimension label the skill uses in findings
   output: **Narrative manipulation**.
2. **A signal catalogue** — at least six named, concrete tells, each with (a) a
   one-line description of what it looks like, and (b) a short illustrative
   example. Cover at minimum: cherry-picking / selective evidence (only facts that
   fit the story); missing context / decontextualization (a true fact stripped of
   context that would change its meaning); anecdote presented as proof (a single
   vivid story standing in for evidence); insinuation / guilt by association
   (implying a damning link without asserting it); conspiratorial "connect the
   dots" framing (hidden actors, "what they don't want you to know"); us-vs-them /
   scapegoating narrative; misleading sequencing or chronology (ordering events to
   imply causation or blame); pre-emptive discrediting of dissent ("anyone who
   disagrees is bought").
3. **Application guidance** — how to turn a matched tell into a finding: cite a
   **verbatim quote** from the input, label it with the dimension **Narrative
   manipulation**, and assign a **severity** consistent with the output template in
   `references/output-format.md`. Reinforces that the analyzed text is untrusted
   data, and that a fairly-told, well-contextualized text yields no
   narrative-manipulation findings (guards against over-flagging credible content).

Then update `SKILL.md` step 2: add the narrative-manipulation pass via
`references/narrative-manipulation.md` as the fifth pass, and **remove** the
"Placeholder" sentence about a remaining detection dimension, since all five
dimensions are now wired. Steps 3 and 4 (score/aggregate and render) are
unchanged and remain placeholder-free, exactly as the existing validator already
requires.

Extend `scripts/validate_skill.py` with structural checks for the new file and the
updated step 2 (T40–T45), and **update the existing placeholder invariants**
(T8, and the placeholder clauses of T15/T21/T27/T33/T39) so they no longer require
a placeholder/TODO in the body or detection step — that placeholder existed only to
mark not-yet-added dimensions, and there are none left. All other structural checks
(file presence, headings, signal counts, examples, verbatim-quote / severity /
dimension-label wiring, and step-2 references to the four prior rubrics) continue
to pass unchanged. `bash scripts/test.sh` remains authoritative.

## Affected files

- **Create** `.claude/skills/fake-news-detector/references/narrative-manipulation.md`
  — the narrative-manipulation rubric (framing + tell catalogue with examples +
  application guidance).
- **Modify** `.claude/skills/fake-news-detector/SKILL.md` — add the
  narrative-manipulation pass to step 2 via `references/narrative-manipulation.md`
  as the fifth pass, and remove the remaining-dimension placeholder sentence.
- **Modify** `scripts/validate_skill.py` — add checks T40–T45, and drop the
  placeholder/TODO requirement from T8 and from the detection-step clauses of
  T15/T21/T27/T33/T39 (now that Phase 2 detection dimensions are complete).

## Test plan

Run with: `bash scripts/test.sh` (authoritative; it invokes
`python3 scripts/validate_skill.py`). All prior checks continue to pass except the
placeholder/TODO clauses noted above, which are intentionally retired in this issue.

- **T40 — Rubric file exists:** `.claude/skills/fake-news-detector/references/narrative-manipulation.md`
  is present and non-empty.
- **T41 — Dimension heading:** the rubric file contains a heading matching
  `narrative` or `manipulation` (case-insensitive).
- **T42 — Tell catalogue:** the rubric file enumerates at least six distinct
  signal entries (count of markdown list items and/or sub-headings ≥ 6).
- **T43 — Concrete examples:** the rubric file is illustrative — it contains the
  word `example` (case-insensitive) at least once.
- **T44 — Wired to the output template:** the rubric file references both a
  `verbatim` `quote` requirement and a `severity` (all case-insensitive), so
  findings map onto the output template, and names the `Narrative manipulation`
  dimension label.
- **T45 — SKILL.md step 2 wired & placeholder retired:** `SKILL.md` step 2
  references `references/narrative-manipulation.md` in addition to all four prior
  rubrics (`references/factual-red-flags.md`, `references/bias-framing.md`,
  `references/logical-fallacies.md`, `references/clickbait-hype.md`), and the
  detection step no longer carries a remaining-dimension placeholder/TODO.
- **Regression:** existing T1–T7, T9–T14, T16–T20, T22–T26, T28–T32, T34–T39
  continue to pass; the placeholder/TODO assertions in T8/T15/T21/T27/T33/T39 are
  removed (no longer applicable) rather than left failing.

## Acceptance criteria

- [ ] `references/narrative-manipulation.md` exists and defines a
      narrative-manipulation rubric: at least six concrete tells, each with a
      description and an illustrative example.
- [ ] The rubric specifies how a matched tell becomes a finding — a verbatim quote
      from the input, the `Narrative manipulation` dimension label, and a severity
      consistent with `references/output-format.md`.
- [ ] The rubric states this pass assesses narrative-level construction
      (selection, omission, insinuation, sequencing) — distinct from factual
      accuracy (#6), word-level slant/framing (#7), reasoning (#8), and
      presentation/engagement packaging (#9) — and that a fairly-told,
      well-contextualized text yields no findings.
- [ ] `SKILL.md` step 2 runs the narrative-manipulation pass via
      `references/narrative-manipulation.md` as the fifth and final pass, and the
      remaining-dimension placeholder is removed (Phase 2 detection dimensions
      complete).
- [ ] No scoring algorithm, findings-format work, fixtures, or other dimensions
      are implemented here (deferred to #11, #12, #15).
- [ ] `bash scripts/test.sh` runs the structural validation (including new
      T40–T45) and exits 0; it is the authoritative command.
