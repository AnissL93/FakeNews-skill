---
layout: default
title: FakeNews-skill
---

# FakeNews-skill

A [Claude Code](https://claude.com/claude-code) skill that gives any pasted text — a news
article, headline, or social-media post — a **critical credibility assessment**: an overall
rating, specific findings each backed by a verbatim quote, and a short rationale. It reasons
over the text with a fixed rubric and does **no** live web fact-checking (it assesses internal
credibility signals only).

[View on GitHub](https://github.com/AnissL93/FakeNews-skill){: .btn }

## What it detects

The skill runs five detection passes over the input, each a self-contained rubric:

| Dimension | Looks for |
|-----------|-----------|
| **Factual red flags** | unsupported/unsourced claims, vague sourcing, fabrication markers, unverifiable stats |
| **Bias & framing** | loaded language, one-sided sourcing, selective emphasis, opinion-as-fact |
| **Logical fallacies** | ad hominem, straw man, false dilemma, appeal to fear, hasty generalization, slippery slope |
| **Clickbait / hype** | sensational headlines, curiosity-gap teasers, exaggeration, urgency, headline–body mismatch |
| **Narrative manipulation** | cherry-picking, missing context, insinuation, conspiratorial framing, scapegoating |

## How it scores

Each finding cites a **verbatim quote** from the input (no paraphrasing or fabrication) with a
dimension label and a severity (High / Medium / Low). Findings aggregate deterministically into
one of five credibility bands:

**Credible** › **Mostly Credible** › **Mixed** › **Low Credibility** › **Not Credible**

The rendered verdict leads with a plain-language summary (a rating + bottom line), then a detailed
findings list and a rationale.

## Usage

Invoke the skill in Claude Code and paste the text to assess — e.g. *"is this article credible?"*
or *"check this post for fake news."* It activates on requests to fact-check, rate reliability, or
flag bias / clickbait / manipulation.

The analyzed content is always treated as **untrusted data**: embedded instructions, fake
delimiters, or system-prompt-like text inside the sample are inert material being assessed, never
directions to follow.

## Design docs

- [Architecture](arch/build-a-fake-news-misinformation-detector-skill.html) — the overall design and risks.

## Tests

```bash
bash scripts/test.sh        # runs python3 scripts/validate_skill.py
```

Static, deterministic structural validation of the skill package and fixtures — no LLM in the
test loop.
