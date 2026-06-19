# Architecture: Fake-News / Misinformation Detector Skill

## Overview

A Claude Code skill that takes arbitrary pasted text — a news article, headline,
or social-media post — and returns a critical credibility assessment: an overall
rating, specific findings each backed by a quoted excerpt, and a short rationale.
It is a self-contained, markdown-driven skill that reasons over the text using a
fixed rubric; it does no live web fact-checking.

## Goals / Non-goals

**Goals**
- Accept arbitrary text (article body, headline, or social post) and analyze it.
- Detect and report misinformation/factual red flags, bias & framing, logical
  fallacies, clickbait/hype, and narrative manipulation.
- Produce deterministic, well-structured output: an overall credibility rating, a
  list of findings with verbatim quoted evidence, and a concise rationale.
- Provide both a user-friendly summary and a detailed breakdown.
- Flag concrete issues on misleading samples; report few/no issues on credible ones.

**Non-goals**
- No live web search or external fact-check APIs (cannot verify claims against the
  world — only assess internal credibility signals).
- No image/video/deepfake analysis.
- No browser integration or automatic URL fetching (user pastes the text).

## Architecture

**Form factor.** A standard skill package: a `SKILL.md` entry point plus reference
files and test fixtures. The detector *is* the rubric — Claude follows the skill's
instructions to analyze the input. No runtime service or external dependency.

**Components**
- `SKILL.md` — metadata and trigger description (when to activate), the end-to-end
  workflow, and instructions to treat the analyzed text strictly as data.
- `references/` — one rubric file per detection dimension (factual red flags, bias
  & framing, fallacies, clickbait, narrative manipulation), each listing concrete
  signals and examples. Loaded progressively to keep context lean.
- Credibility rating scale + output template — a fixed banded scale (e.g. a small
  ordinal set with definitions) and the exact rendered layout for summary + detail.
- `fixtures/` — paired sample inputs (one misleading, one credible) and expected
  findings, used to validate the acceptance criteria.

**Data flow**
1. User invokes the skill with pasted text.
2. The text is captured as untrusted *data* (never as instructions).
3. The skill runs each detection dimension as a pass, collecting candidate findings
   that each cite a verbatim quote from the input.
4. Findings are scored and aggregated into one overall credibility rating per the scale.
5. Output is rendered: a short user-friendly verdict on top, then the detailed
   findings list and rationale.

**Key choices (and why)**
- Pure markdown skill, no code runtime — matches the "skill" deliverable, zero deps,
  trivially portable.
- Fixed rubric + banded rating scale — drives *deterministic, repeatable* verdicts
  rather than ad-hoc judgment.
- Mandatory verbatim quoting — every finding must anchor to text actually present,
  which prevents fabricated evidence and keeps the output actionable.
- Progressive disclosure of per-dimension reference files — keeps each analysis pass
  focused and the base prompt small.

## Risks

- **Inconsistent / subjective ratings** across runs — mitigated by a banded scale
  with explicit definitions and rubric-driven passes.
- **Fabricated or paraphrased "quotes"** — mitigated by requiring verbatim excerpts
  that must be locatable in the input.
- **Over-flagging credible content** — strong, well-sourced articles must score
  clean; fixtures must include a credible sample to guard against false positives.
- **Prompt injection from the analyzed content** — the input may contain text that
  looks like instructions; the skill must treat all input as inert data.

## Work breakdown

- Phase 1: Skill foundation
  - Scaffold SKILL.md with metadata, trigger description, and input handling
  - Define the credibility rating scale and output template
  - Implement factual red-flag / misinformation detection pass
- Phase 2: Detection dimensions
  - Add bias & framing detection
  - Add logical-fallacy detection
  - Add clickbait / hype detection
  - Add narrative-manipulation detection
- Phase 3: Verdict synthesis & output
  - Implement findings format with verbatim quoted evidence
  - Implement overall credibility scoring and rationale synthesis
  - Add user-friendly summary layer above the detailed breakdown
- Phase 4: Robustness & validation
  - Treat analyzed content as untrusted data (prompt-injection hardening)
  - Add misleading and credible sample fixtures
  - Add acceptance check verifying flags, quotes, and rating on fixtures
