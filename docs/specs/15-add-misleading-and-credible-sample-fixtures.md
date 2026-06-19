# Spec: Add misleading and credible sample fixtures

## Problem

Phase 4 (Robustness & validation) of the fake-news-detector skill (#1) calls for
paired sample inputs that guard the two headline acceptance criteria: a misleading
article must surface concrete flags, and a credible, well-sourced article must come
back clean. This issue adds those fixtures — one misleading, one credible — each
carrying its expected outcome (rating + expected findings with quoted evidence), and
extends the existing validator so the fixtures are checked for internal consistency.

Scope is the fixtures themselves plus *static* validation of their structure. Actually
running the skill against the fixtures and asserting its live output is the separate
follow-up issue ("Add acceptance check verifying flags, quotes, and rating on
fixtures"); it is out of scope here.

## Approach

Add a `fixtures/` directory under the skill package with two markdown files, each
using YAML frontmatter (already parseable by the `pyyaml` dependency the validator
imports) for machine-checkable expectations plus a content body holding the article
text to analyze:

```markdown
---
kind: misleading            # or: credible
expected_rating: Not Credible   # one of the five canonical bands
expected_findings:          # [] for the credible fixture
  - dimension: Factual red flag
    severity: High
    quote: "exact verbatim span copied from the body below"
---

<article body — the untrusted content a user would paste>
```

The misleading fixture is authored so each `expected_findings` quote is an exact
substring of its body, spans at least two distinct detection dimensions, and its
`expected_rating` is a low band. The credible fixture is well-sourced, in-text
attributed, neutrally framed, has `expected_findings: []`, and a high-band rating.

Validation lives in `scripts/validate_skill.py` as new checks (run last in `main`,
following the existing `T*` numbering). The checks confirm both fixtures exist and
parse, the `kind`/`expected_rating`/dimension/severity values are drawn from the
canonical vocabularies already defined in the references, the misleading/credible
band split holds, finding counts match each kind, and — the key guarantee — every
expected-finding quote is verbatim-locatable in its fixture body (mirroring the
verbatim-quote rule in `references/findings-format.md`, including ellipsis-joined
fragments and the permitted omission marker). No new dependency; reuse `yaml` and the
existing `fail(check, message)` helper.

## Affected files

- `.claude/skills/fake-news-detector/fixtures/misleading-sample.md` — create: misleading
  article body + frontmatter with a low-band `expected_rating` and ≥3 expected findings
  across ≥2 dimensions, each quoting a verbatim span of the body.
- `.claude/skills/fake-news-detector/fixtures/credible-sample.md` — create: credible,
  well-sourced article body + frontmatter with a high-band `expected_rating` and
  `expected_findings: []`.
- `scripts/validate_skill.py` — modify: add fixture-validation checks and call them from
  `main()`.

## Test plan

Run with: `python3 scripts/validate_skill.py` (this is what `scripts/test.sh` executes).

- Both fixtures present: `fixtures/misleading-sample.md` and `fixtures/credible-sample.md`
  exist and are non-empty; missing/empty either one fails.
- Parse shape: each fixture has YAML frontmatter that loads to a mapping with `kind`,
  `expected_rating`, and `expected_findings`, plus a non-empty content body after the
  frontmatter.
- `kind` values: the misleading fixture declares `kind: misleading`, the credible fixture
  declares `kind: credible`; any other value fails.
- Band vocabulary: each `expected_rating` is one of the five canonical bands
  (`Credible`, `Mostly Credible`, `Mixed`, `Low Credibility`, `Not Credible`); an unknown
  band fails.
- Band split: the misleading fixture's rating is a low band (`Mixed`, `Low Credibility`,
  or `Not Credible`) and the credible fixture's rating is a high band (`Credible` or
  `Mostly Credible`); a misleading fixture rated `Credible` fails.
- Finding counts: the misleading fixture has ≥3 expected findings spanning ≥2 distinct
  dimensions; the credible fixture has exactly 0 expected findings.
- Finding vocabulary: every expected finding's `dimension` is one of the five canonical
  labels (`Factual red flag`, `Bias & framing`, `Logical fallacy`, `Clickbait / hype`,
  `Narrative manipulation`) and its `severity` is one of `High`/`Medium`/`Low`.
- Verbatim quotes: every expected-finding `quote` is locatable in its fixture body —
  each ellipsis-joined fragment is an exact substring of the body — except the literal
  omission marker `(no quotable excerpt — omission)`; a paraphrased or absent quote fails.
- Full suite green: `python3 scripts/validate_skill.py` exits 0 with all prior `T*`
  checks still passing.

## Acceptance criteria

- [ ] `fixtures/misleading-sample.md` and `fixtures/credible-sample.md` exist under the
      skill package.
- [ ] The misleading fixture carries a low-band `expected_rating` and ≥3 expected findings
      across ≥2 dimensions, each anchored to a verbatim quote present in its body.
- [ ] The credible fixture carries a high-band `expected_rating` and `expected_findings: []`.
- [ ] All dimension/severity/band values in the fixtures use the canonical vocabularies
      defined in the existing reference files.
- [ ] `scripts/validate_skill.py` validates fixture presence, structure, vocabularies,
      the misleading/credible band split, finding counts, and verbatim-quote locatability.
- [ ] `python3 scripts/validate_skill.py` passes.
