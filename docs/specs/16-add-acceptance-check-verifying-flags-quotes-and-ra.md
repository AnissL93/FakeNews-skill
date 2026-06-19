# Spec: Add acceptance check verifying flags, quotes, and rating on fixtures

## Problem

Phase 4 (Robustness & validation) of the fake-news-detector skill (#1) asks for an
acceptance check that verifies the three things the skill promises to produce — the
**flags** (findings), their **quotes** (verbatim evidence), and the overall **rating** —
against the sample fixtures.

Issue #15 added the two fixtures (`misleading-sample.md`, `credible-sample.md`) and
*structural* validation that each fixture file is internally well-formed: it parses, its
`kind`/`expected_rating`/dimension/severity values are individually drawn from canonical
vocabularies, and every quote is verbatim-locatable in its body. Spec #15 explicitly
deferred this issue as the follow-up.

The skill has no executable runtime — `scripts/test.sh` runs only
`scripts/validate_skill.py`, and CI has no LLM in the loop, so the acceptance check must
be **deterministic and static**. The gap this issue closes is the *acceptance contract*
layer: assert that each fixture, taken as a whole, encodes the headline acceptance
criteria of the skill (a misleading article surfaces concrete flags with quoted evidence
and a low rating; a credible article comes back clean with a high rating), and that the
vocabularies the fixtures use are the same ones the skill's own reference docs define —
so fixtures, validator, and documentation cannot silently drift apart.

## Approach

Add a single new check function `validate_fixture_acceptance()` to
`scripts/validate_skill.py`, called last in `main()` (after `validate_fixtures()`),
numbered `T79`+ to continue the existing `T*` scheme. It reuses the already-parsed
fixture data and the existing `fail(check, message)` and `parse_fixture(...)` helpers — no
new dependency and no new files beyond the validator edit.

The function asserts two things the structural checks (#15) do not:

1. **Vocabulary is sourced from the reference docs, not just hardcoded.** Derive the set
   of allowed rating bands from `references/output-format.md` and the set of dimension
   labels from `references/findings-format.md` (both already contain these as literal
   text — see the existing `validate_output_format`/`validate_findings_format` checks).
   Assert every `expected_rating` and every finding `dimension` used in the fixtures is
   present in the corresponding reference doc. This guarantees the fixtures stay in sync
   with the documented contract: renaming a band or dimension in the docs without
   updating the fixtures (or vice versa) fails the check.

2. **Each fixture satisfies its acceptance contract across the three named axes.** Group
   the assertions explicitly so failures map to "flags", "quotes", or "rating":
   - **Flags** — the misleading fixture has ≥1 expected finding; the credible fixture has
     exactly zero.
   - **Quotes** — for the misleading fixture, every expected finding carries a non-empty
     quote that is verbatim-locatable in the body (reuse `quote_is_locatable`), and no
     finding uses the omission marker as its only evidence basis is allowed but every
     non-omission quote must be an exact substring.
   - **Rating** — the misleading fixture's `expected_rating` is a low band and the
     credible fixture's is a high band, consistent with each fixture's flag count
     (findings present ⟺ low band; clean ⟺ high band).

   Each assertion emits a clear, axis-labelled failure message (e.g.
   `T81 failed: misleading fixture has flags but a high-band rating`).

Apply YAGNI: no live skill invocation, no scoring re-implementation, no new config. The
check is purely a cross-consistency assertion over data already loaded by the validator.

## Affected files

- `scripts/validate_skill.py` — modify: add `validate_fixture_acceptance()` (checks
  `T79`–`T82`), invoke it from `main()` after `validate_fixtures()`, and reuse the
  existing parse/locatability helpers. May refactor `validate_fixtures()` to return the
  parsed fixture data so it is not parsed twice.

## Test plan

Run with: `python3 scripts/validate_skill.py` (this is what `scripts/test.sh` executes).

- Vocabulary sync — rating: every `expected_rating` used by the fixtures appears verbatim
  in `references/output-format.md`; a fixture rating absent from that doc fails.
- Vocabulary sync — dimensions: every finding `dimension` used by the fixtures appears
  verbatim in `references/findings-format.md`; a dimension absent from that doc fails.
- Flags axis: the misleading fixture has ≥1 expected finding and the credible fixture has
  exactly 0; a misleading fixture with no findings, or a credible fixture with any
  finding, fails.
- Quotes axis: every non-omission quote in the misleading fixture is an exact substring of
  its body (ellipsis-joined fragments each located individually); a paraphrased or absent
  quote fails.
- Rating axis: the misleading fixture's rating is a low band and the credible fixture's is
  a high band, consistent with each fixture's flag count; a misleading fixture rated in a
  high band (or credible in a low band) fails.
- Axis-labelled messages: each failure message names the offending fixture and the axis
  (flags / quotes / rating / vocabulary) so the cause is unambiguous.
- Full suite green: `python3 scripts/validate_skill.py` exits 0 with all prior `T1`–`T78`
  checks still passing on the current fixtures.

## Acceptance criteria

- [ ] `scripts/validate_skill.py` contains an acceptance check that verifies, per fixture,
      the **flags** (presence/absence of findings), the **quotes** (verbatim-locatable
      evidence), and the **rating** (correct band for the fixture's kind).
- [ ] The check sources its allowed rating bands and dimension labels from
      `references/output-format.md` and `references/findings-format.md`, failing if a
      fixture uses a value absent from those docs (drift protection).
- [ ] The misleading fixture is asserted to surface ≥1 flag with verbatim quotes and a
      low-band rating; the credible fixture is asserted to be clean with a high-band
      rating.
- [ ] Failure messages identify the fixture and the axis (flags / quotes / rating /
      vocabulary).
- [ ] The new check is invoked from `main()` and `python3 scripts/validate_skill.py`
      passes on the current fixtures.
