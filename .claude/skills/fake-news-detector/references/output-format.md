# Credibility Rating Scale

Use `references/scoring.md` to aggregate formatted findings into exactly one of these bands.

- **Credible** - no material red flags; claims are sourced/verifiable in-text and framing is fair.
- **Mostly Credible** - minor issues (mild framing, a weak source) that do not undermine the core.
- **Mixed** - a blend of substantiated and unsupported/misleading elements; read with caution.
- **Low Credibility** - multiple significant red flags (unsupported claims, heavy bias, fallacies).
- **Not Credible** - pervasive misinformation signals, fabrication markers, or manipulation throughout.

# Output Template

Format each finding according to the per-finding rules in `references/findings-format.md`.

```markdown
## Verdict

**Rating:** <Credible | Mostly Credible | Mixed | Low Credibility | Not Credible>

<One-sentence plain-language takeaway.>

## Findings

<!-- If there are findings, list one item per issue and OMIT the empty-state line below: -->

- **<Dimension> (<Severity>):** "<verbatim quote from the input>"
  <One-line explanation of the issue.>

<!-- Otherwise, when there are no findings, drop the list above and emit only this line: -->

No significant issues found.

## Rationale

<Concise paragraph tying the findings to the selected credibility rating.>
```
