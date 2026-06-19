# Spec: Implement overall credibility scoring and rationale synthesis

Issue: #12 — Phase 3 (Verdict synthesis & output) of #1.

## Problem

Two pieces of Phase 3 are already in place: #5 defined the five-band rating
scale and the document layout (`references/output-format.md`), and #11 defined
the per-finding entry — dimension label, severity vocabulary, verbatim quoting,
ordering/dedup (`references/findings-format.md`). What is still missing is the
*bridge* between them:

- **No scoring rule.** `SKILL.md` step 3 says "Score and aggregate findings
  against the credibility rating scale in `references/output-format.md`," but
  `output-format.md` only lists the five bands with prose definitions. There is
  no rule that maps an actual set of findings (their severities and dimension
  spread) onto exactly one band. Two runs over the same findings could pick
  different bands — the "inconsistent / subjective ratings" risk from the arch.
- **No rationale discipline.** The template has a `## Rationale` slot, but
  nothing says what belongs in it: that it must tie the *listed* findings to the
  *chosen* band, stay a single concise paragraph, and introduce no new claims.

This issue delivers the **scoring rubric** (findings → one band, deterministic)
and the **rationale-synthesis rules**, then wires `SKILL.md` step 3 to them.

Scope boundary (YAGNI): this issue defines *how findings aggregate into a band
and how the rationale paragraph is written*. It does **not** add or change any
detection pass (#6–#10), the per-finding format (#11), or the band definitions
and document layout (#5) — those are consumed as-is. It does **not** build the
user-friendly summary layer above the breakdown (that is #13) or any fixtures
(#15). No code runtime is added; this is rubric markdown plus validator checks.

## Approach

Create one reference file
`.claude/skills/fake-news-detector/references/scoring.md`, following the arch's
progressive-disclosure `references/` convention. It is the single source of
truth for **aggregation and rationale**, while `output-format.md` stays the
source of truth for the band *definitions* and document layout, and
`findings-format.md` for the per-finding entry. It contains:

1. **Inputs to scoring** — the deduped findings list from step 2, each already
   carrying a canonical dimension label and a `High` / `Medium` / `Low`
   severity per `references/findings-format.md`. Scoring reads severities and
   how many distinct dimensions are involved; it does not re-judge findings.

2. **Banding rule** — a deterministic mapping evaluated **top-down, first match
   wins**, stated in terms of the counts of High (H), Medium (M), and Low (L)
   findings and the number of distinct dimensions spanned:
   - **Not Credible** — `H ≥ 3`, or (`H ≥ 2` and findings span ≥ 2 dimensions):
     pervasive or cross-cutting material misinformation/manipulation.
   - **Low Credibility** — `H ≥ 1`, or `M ≥ 3`: at least one materially
     misleading finding, or several interpretation-coloring ones.
   - **Mixed** — `1 ≤ M ≤ 2` and `H = 0`: a blend of sound and weak elements.
   - **Mostly Credible** — only Low findings (`L ≥ 1`, `H = M = 0`): minor or
     stylistic issues that do not undermine the core.
   - **Credible** — no findings at all.
   These are mutually exclusive once evaluated in order, so every findings set
   maps to exactly one band.

3. **Boundary note** — a short rule that the per-finding severity assignment
   (already an analyst judgment per #11) is where nuance lives; the count-based
   rule above is then applied mechanically so the verdict is reproducible. No
   per-finding re-weighting beyond its assigned severity.

4. **Rationale-synthesis rules** — the `## Rationale` paragraph must:
   - be a **single concise paragraph**;
   - reference the **actual listed findings** that drove the band, leading with
     the highest-severity ones, and name the pattern (e.g. counts/spread) that
     selected the band;
   - be **consistent with the chosen band** and the findings list — introduce
     **no new claims, quotes, or findings** not already in the list;
   - for a clean input (**Credible**, no findings), briefly state why no
     material red flags surfaced rather than inventing reassurance.

5. **A worked example** — a small findings set (e.g. one High + one Low) shown
   resolving to its band via the rule, plus the matching one-paragraph
   rationale. Reinforces that the analyzed text is untrusted data.

Then **wire it in**:
- `references/output-format.md` — add a one-line pointer from the rating-scale
  section to `references/scoring.md` for the aggregation rule (additive only;
  bands, markers, and template skeleton are unchanged).
- `SKILL.md` — update **step 3** so it scores and aggregates per
  `references/scoring.md`, *in addition to* the band scale in
  `references/output-format.md`. Steps 1, 2, and 4 are unchanged.

Extend `scripts/validate_skill.py` with structural checks for the new file and
the updated step-3 wiring (T53–T58). All existing checks (T1–T52) continue to
pass unchanged — the change is additive (output-format.md gains one pointer
line; step 3 gains a second reference). `bash scripts/test.sh` stays
authoritative.

## Affected files

- **Create** `.claude/skills/fake-news-detector/references/scoring.md` — the
  banding rule (findings → one of five bands), the boundary note, the
  rationale-synthesis rules, and a worked example.
- **Modify** `.claude/skills/fake-news-detector/references/output-format.md` —
  add a one-line pointer from the rating-scale section to
  `references/scoring.md` (additive only).
- **Modify** `.claude/skills/fake-news-detector/SKILL.md` — step 3 references
  `references/scoring.md` for aggregation in addition to
  `references/output-format.md` for the band scale.
- **Modify** `scripts/validate_skill.py` — add checks T53–T58.

## Test plan

Run with: `bash scripts/test.sh` (authoritative; it invokes
`python3 scripts/validate_skill.py`). Existing checks T1–T52 continue to pass
unchanged.

- **T53 — Reference file exists:**
  `.claude/skills/fake-news-detector/references/scoring.md` is present and
  non-empty.
- **T54 — Scoring heading:** the file contains a heading matching `scor`,
  `aggregat`, or `rating` (case-insensitive).
- **T55 — All five bands mapped:** the file names each band — `Credible`,
  `Mostly Credible`, `Mixed`, `Low Credibility`, `Not Credible`
  (case-insensitive) — in its banding rule.
- **T56 — Severity-driven rule:** the file references all three severities
  (`High`, `Medium`, `Low`, case-insensitive) as inputs to the banding rule, so
  the mapping is severity-driven rather than ad-hoc.
- **T57 — Rationale-synthesis rules:** the file contains `rationale`
  (case-insensitive) and states the no-new-claims / consistency discipline — it
  contains at least one of `consistent` / `no new` / `not introduce` /
  `only`, and includes a worked `example` (case-insensitive).
- **T58 — SKILL.md wired up:** step 3 references both `references/scoring.md`
  and `references/output-format.md`, with no `placeholder`/`TODO`; and
  `output-format.md` points to `references/scoring.md`.
- **Regression:** existing T1–T52 continue to pass unchanged.

## Acceptance criteria

- [ ] `references/scoring.md` exists and defines a deterministic banding rule
      that maps a findings set (by High/Medium/Low severity counts and
      dimension spread) onto exactly one of the five bands `Credible`,
      `Mostly Credible`, `Mixed`, `Low Credibility`, `Not Credible`.
- [ ] The rule is evaluated top-down / first-match so every findings set yields
      exactly one band, and `Credible` corresponds to no findings.
- [ ] The file defines rationale-synthesis rules: a single concise paragraph
      that ties the listed findings to the chosen band, leads with the
      highest-severity findings, stays consistent with the band, and introduces
      no new claims/quotes/findings; plus a worked example.
- [ ] `SKILL.md` step 3 scores and aggregates per `references/scoring.md` in
      addition to the band scale in `references/output-format.md`, and
      `output-format.md` points to `references/scoring.md` from its rating-scale
      section.
- [ ] No detection pass, per-finding format, band definitions, summary layer, or
      fixtures are added or changed here (deferred to / owned by #5–#11, #13,
      #15).
- [ ] `bash scripts/test.sh` runs the structural validation (including new
      T53–T58) and exits 0; it is the authoritative command.
