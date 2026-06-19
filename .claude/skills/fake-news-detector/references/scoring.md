# Credibility Scoring And Rationale

Use this reference after the detection passes have produced the deduped findings list formatted by `references/findings-format.md`. Scoring reads only each finding's canonical dimension label and assigned `High`, `Medium`, or `Low` severity, plus how many distinct dimensions the findings span. Do not re-judge, re-weight, or add findings during scoring.

## Banding Rule

Apply these rules top-down; the first match wins. Let `H` be the count of High findings, `M` the count of Medium findings, `L` the count of Low findings, and `D` the count of distinct dimensions represented in the findings.

- **Not Credible** - `H >= 3`, or (`H >= 2` and `D >= 2`): pervasive or cross-cutting material misinformation/manipulation.
- **Low Credibility** - `H >= 1`, or `M >= 3`: at least one materially misleading finding, or several interpretation-coloring ones.
- **Mixed** - `1 <= M <= 2` and `H = 0`: a blend of sound and weak elements.
- **Mostly Credible** - `L >= 1`, `H = 0`, and `M = 0`: minor or stylistic issues that do not undermine the core.
- **Credible** - no findings at all: no material red flags surfaced.

Because the rule is evaluated in order, every findings set maps to exactly one rating band from `references/output-format.md`.

## Boundary

Nuance belongs in the per-finding severity assignment described in `references/findings-format.md`. Once severity is assigned, apply the count-based rule mechanically so repeated runs over the same findings produce the same verdict. Do not perform per-finding weighting beyond the assigned severity.

## Rationale Rules

The `## Rationale` section must be a single concise paragraph. It must reference the actual listed findings that drove the band, lead with the highest-severity findings, and name the pattern, count, or dimension spread that selected the band. Keep the rationale consistent with the selected rating and the findings list; introduce no new claims, quotes, or findings. For a clean `Credible` result with no findings, briefly state that no material red flags surfaced instead of inventing reassurance.

## Worked Example

Findings:

```markdown
- **Factual red flag (High):** "The city secretly replaced every ballot overnight"
  Makes a central election claim without visible support.

- **Clickbait / hype (Low):** "what they do not want you to know"
  Uses conspiratorial teaser framing.
```

Scoring: `H = 1`, `M = 0`, `L = 1`, and `D = 2`. The top-down rule reaches **Low Credibility** because `H >= 1`.

Rationale: The Low Credibility rating is driven by one High finding, the unsupported central claim that "The city secretly replaced every ballot overnight"; the additional Low clickbait finding reinforces the presentation issue but does not change the band selected by the High-severity count.
