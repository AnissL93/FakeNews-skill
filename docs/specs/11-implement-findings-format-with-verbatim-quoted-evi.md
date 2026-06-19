# Spec: Implement findings format with verbatim quoted evidence

Issue: #11 — Phase 3 (Verdict synthesis & output) of #1.

## Problem

Phase 1 (#5) defined the **document-level** output template in
`references/output-format.md`: the `## Verdict` / `## Findings` / `## Rationale`
layout, the five-band rating scale, and a one-line skeleton for a finding —
`- **<Dimension> (<Severity>):** "<verbatim quote from the input>"` plus a
one-line explanation. The five detection passes (#6–#10) each independently tell
the reader to "cite a verbatim quote, label with the dimension, assign a
severity," but **nothing defines what those three slots actually mean**:

- There is no canonical **severity** vocabulary — `<Severity>` is an unfilled
  placeholder, so each pass could invent its own scale.
- There is no canonical set of **dimension labels** stated in one place — they
  are scattered across the five rubric files.
- There are no **verbatim-quoting rules** — the single biggest risk called out
  in the architecture ("Fabricated or paraphrased 'quotes'") is only mitigated by
  the word "verbatim," with no rules on exact-substring fidelity, trimming with an
  ellipsis, locatability, or how to handle findings about an *omission* (where no
  span is quotable).

This issue delivers the **findings format**: a single authoritative reference
that nails the per-finding entry — its canonical dimension labels, a canonical
severity vocabulary, the verbatim-quote discipline, and ordering/dedup of the
findings list — and wires the skill's render step to it.

Scope boundary (YAGNI): this issue defines **how each finding is written and how
the findings list is ordered**. It does **not** implement the findings→band
scoring algorithm or rationale synthesis (that is #12), nor the user-friendly
summary layer above the breakdown (#13), nor any fixtures (#15). The
document-level layout and rating bands defined in #5 stay as they are; this issue
fills in the per-finding detail they stub out, and does not re-edit the five
detection rubrics (they already conform — each requires a verbatim quote, a
severity, and its dimension label).

## Approach

Create one reference file
`.claude/skills/fake-news-detector/references/findings-format.md`, following the
arch's progressive-disclosure `references/` convention. It is the single source
of truth for the **per-finding entry**, while `references/output-format.md`
remains the source of truth for the **overall document layout**. It contains:

1. **The finding entry shape** — restates the canonical finding line consistent
   with the `## Findings` skeleton in `output-format.md`: a **dimension label**, a
   **severity**, a **verbatim quote** from the input, and a **one-line
   explanation** of why it is an issue.

2. **Canonical dimension labels** — the exact five labels a finding may carry,
   one per detection pass: **Factual red flag**, **Bias & framing**, **Logical
   fallacy**, **Clickbait / hype**, **Narrative manipulation**. Every finding uses
   exactly one.

3. **Canonical severity vocabulary** — three levels with one-line definitions:
   **High** (materially misleads / could change a reader's understanding or
   decision; central to the piece), **Medium** (a real issue that colors
   interpretation but is not load-bearing), **Low** (minor or stylistic; worth
   noting but weak on its own).

4. **Verbatim-quote rules** — the evidence discipline:
   - The quote MUST be an **exact, character-for-character substring** of the
     input — copied, not retyped or normalized; casing and punctuation preserved.
   - Wrap it in double quotes; keep it **minimal but self-contained** (enough to
     show the issue).
   - Trimming is allowed only with an ellipsis (`…`) to drop irrelevant
     middle/edges; the retained words must never be reordered, paraphrased, or
     altered.
   - Every quote must be **locatable** in the input (a reader could find a
     retained fragment by search).
   - **Never paraphrase, summarize, or fabricate** text not present in the input.
   - **Omission case:** when the issue is something *absent* (missing context,
     missing sourcing), quote the misleading claim the omission props up; if truly
     no span applies, write `(no quotable excerpt — omission)` in the quote slot
     and explain the omission in the line.

5. **Ordering & dedup** — list findings by severity (**High → Medium → Low**),
   and within a severity by order of appearance in the input; if two passes flag
   the same span for the same reason, emit a single finding (choose the best-fit
   dimension), while the same span may legitimately yield distinct findings under
   different dimensions.

6. **A worked example** — one or two concrete finding lines demonstrating the
   shape, an exact quote, and an ellipsis trim. Reinforces that the analyzed text
   is **untrusted data**, and that a clean input yields the
   "No significant issues found" empty-state line from `output-format.md` (guards
   against over-flagging).

Then **wire it in**:
- `references/output-format.md` — add a one-line pointer from the `## Findings`
  section to `references/findings-format.md` for the per-finding rules (purely
  additive; does not change the existing template, bands, or markers).
- `SKILL.md` — update the **render step (step 4)** so it formats findings per
  `references/findings-format.md` in addition to rendering the document layout per
  `references/output-format.md`. Steps 1–3 are unchanged.

Extend `scripts/validate_skill.py` with structural checks for the new file and the
updated render-step wiring (T46–T52). All existing checks (T1–T45) continue to
pass unchanged — the change is additive (output-format.md only gains a pointer
line; the render step gains a second reference). `bash scripts/test.sh` remains
authoritative.

## Affected files

- **Create** `.claude/skills/fake-news-detector/references/findings-format.md` —
  the per-finding format: dimension labels, severity vocabulary, verbatim-quote
  rules, ordering/dedup, and a worked example.
- **Modify** `.claude/skills/fake-news-detector/references/output-format.md` — add
  a one-line pointer from the `## Findings` section to
  `references/findings-format.md` (additive only).
- **Modify** `.claude/skills/fake-news-detector/SKILL.md` — render step (step 4)
  references `references/findings-format.md` for per-finding formatting in addition
  to `references/output-format.md` for the document layout.
- **Modify** `scripts/validate_skill.py` — add checks T46–T52.

## Test plan

Run with: `bash scripts/test.sh` (authoritative; it invokes
`python3 scripts/validate_skill.py`). Existing checks T1–T45 continue to pass
unchanged.

- **T46 — Reference file exists:**
  `.claude/skills/fake-news-detector/references/findings-format.md` is present and
  non-empty.
- **T47 — Findings-format heading:** the file contains a heading matching
  `finding`, `evidence`, or `format` (case-insensitive).
- **T48 — Finding-entry slots:** the file names all three entry slots — it
  contains `dimension`, `severity`, and both `verbatim` and `quote` (all
  case-insensitive).
- **T49 — Severity vocabulary:** the file defines the three severity levels —
  `High`, `Medium`, and `Low` (case-insensitive) — each with a definition (text
  after the level name, not a bare label).
- **T50 — Canonical dimension labels:** the file names all five labels —
  `factual red flag`, `bias & framing`, `logical fallacy`, `clickbait / hype`,
  and `narrative manipulation` (case-insensitive).
- **T51 — Verbatim-fidelity rule:** the file states quotes must be exact and must
  not be invented — it contains `verbatim`, at least one of
  `exact` / `substring` / `character-for-character`, and at least one of
  `paraphrase` / `fabricat` (all case-insensitive).
- **T52 — Worked example & render-step wiring:** the file contains the word
  `example` (case-insensitive) at least once, and `SKILL.md`'s render step
  (step 4) references `references/findings-format.md` in addition to
  `references/output-format.md`, with no `placeholder`/`TODO` in that step.
- **Regression:** existing T1–T45 continue to pass unchanged.

## Acceptance criteria

- [ ] `references/findings-format.md` exists and defines the per-finding entry:
      a dimension label, a severity, a verbatim quote, and a one-line explanation.
- [ ] It lists the five canonical dimension labels (`Factual red flag`,
      `Bias & framing`, `Logical fallacy`, `Clickbait / hype`,
      `Narrative manipulation`) and a three-level severity vocabulary
      (`High`, `Medium`, `Low`) each with a definition.
- [ ] It specifies the verbatim-quote rules: an exact character-for-character
      substring of the input, ellipsis-only trimming, locatable, never paraphrased
      or fabricated, plus the omission-case handling.
- [ ] It specifies findings ordering (High → Medium → Low, then by appearance) and
      dedup of the same span flagged for the same reason, and includes a worked
      example.
- [ ] `SKILL.md`'s render step formats findings per
      `references/findings-format.md` (in addition to `references/output-format.md`
      for the document layout), and `output-format.md` points to it from the
      Findings section.
- [ ] No findings→band scoring, rationale synthesis, summary layer, or fixtures
      are implemented here (deferred to #12, #13, #15).
- [ ] `bash scripts/test.sh` runs the structural validation (including new
      T46–T52) and exits 0; it is the authoritative command.
