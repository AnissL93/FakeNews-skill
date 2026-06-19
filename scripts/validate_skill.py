#!/usr/bin/env python3
"""Validate the fake-news-detector skill scaffold."""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
SKILL_ROOT = ROOT / ".claude" / "skills" / "fake-news-detector"
SKILL_PATH = SKILL_ROOT / "SKILL.md"
OUTPUT_FORMAT_PATH = SKILL_ROOT / "references" / "output-format.md"
FACTUAL_RED_FLAGS_PATH = SKILL_ROOT / "references" / "factual-red-flags.md"
BIAS_FRAMING_PATH = SKILL_ROOT / "references" / "bias-framing.md"
LOGICAL_FALLACIES_PATH = SKILL_ROOT / "references" / "logical-fallacies.md"
CLICKBAIT_HYPE_PATH = SKILL_ROOT / "references" / "clickbait-hype.md"
NARRATIVE_MANIPULATION_PATH = SKILL_ROOT / "references" / "narrative-manipulation.md"
FINDINGS_FORMAT_PATH = SKILL_ROOT / "references" / "findings-format.md"
SCORING_PATH = SKILL_ROOT / "references" / "scoring.md"
SUMMARY_FORMAT_PATH = SKILL_ROOT / "references" / "summary-format.md"


def fail(check: str, message: str) -> None:
    print(f"{check} failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_skill() -> tuple[dict[str, object], str]:
    if not SKILL_PATH.is_file():
        fail("T1", f"{SKILL_PATH.relative_to(ROOT)} is missing")

    text = SKILL_PATH.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        fail("T2", "SKILL.md must start with YAML frontmatter delimited by ---")

    parts = text.split("---\n", 2)
    if len(parts) != 3:
        fail("T2", "SKILL.md must contain closing --- for YAML frontmatter")

    try:
        frontmatter = yaml.safe_load(parts[1])
    except yaml.YAMLError as exc:
        fail("T2", f"frontmatter is not valid YAML: {exc}")

    if not isinstance(frontmatter, dict):
        fail("T2", "frontmatter must parse to a YAML mapping")

    return frontmatter, parts[2]


def require_step(body: str, step_number: int) -> str:
    match = re.search(rf"^\s*{step_number}\.\s+(.+)$", body, flags=re.MULTILINE)
    if not match:
        fail("T15", f"workflow step {step_number} is missing")
    return match.group(1)


def validate_output_format() -> None:
    if not OUTPUT_FORMAT_PATH.is_file():
        fail("T10", f"{OUTPUT_FORMAT_PATH.relative_to(ROOT)} is missing")

    text = OUTPUT_FORMAT_PATH.read_text(encoding="utf-8")
    if not text.strip():
        fail("T10", f"{OUTPUT_FORMAT_PATH.relative_to(ROOT)} is empty")

    if not re.search(r"^#{1,6}\s+.*(?:rating|scale).*$", text, flags=re.IGNORECASE | re.MULTILINE):
        fail("T11", "output-format.md must contain a rating or scale heading")

    for band in ("Credible", "Mostly Credible", "Mixed", "Low Credibility", "Not Credible"):
        band_pattern = re.escape(band)
        if not re.search(rf"\b{band_pattern}\b", text, flags=re.IGNORECASE):
            fail("T12", f"output-format.md must define the {band} band")
        if not re.search(
            rf"^\s*(?:[-*]\s*)?(?:\*\*)?{band_pattern}(?:\*\*)?\s*(?:[-:—–]\s+|\s+-\s+)\S+",
            text,
            flags=re.IGNORECASE | re.MULTILINE,
        ):
            fail("T12", f"the {band} band must include a one-line definition")

    for marker in ("Verdict", "Findings", "Rationale"):
        if not re.search(rf"\b{marker}\b", text, flags=re.IGNORECASE):
            fail("T13", f"output-format.md must contain a {marker} marker")

    text_lower = text.lower()
    if "verbatim" not in text_lower or "quote" not in text_lower:
        fail("T14", "findings template must require a verbatim quote")
    if not re.search(r"\bno\s+(?:significant\s+issues|issues\s+found)\b", text, flags=re.IGNORECASE):
        fail("T14", "findings template must define the empty-findings line")


def validate_factual_red_flags() -> None:
    if not FACTUAL_RED_FLAGS_PATH.is_file():
        fail("T16", f"{FACTUAL_RED_FLAGS_PATH.relative_to(ROOT)} is missing")

    text = FACTUAL_RED_FLAGS_PATH.read_text(encoding="utf-8")
    if not text.strip():
        fail("T16", f"{FACTUAL_RED_FLAGS_PATH.relative_to(ROOT)} is empty")

    if not re.search(r"^#{1,6}\s+.*(?:factual|red flag|misinformation).*$", text, flags=re.IGNORECASE | re.MULTILINE):
        fail("T17", "factual-red-flags.md must contain a factual/red flag/misinformation heading")

    signal_entries = re.findall(r"^\s*(?:[-*]\s+\S|#{2,6}\s+\S)", text, flags=re.MULTILINE)
    if len(signal_entries) < 6:
        fail("T18", "factual-red-flags.md must enumerate at least six signal entries")

    if not re.search(r"\bexample\b", text, flags=re.IGNORECASE):
        fail("T19", "factual-red-flags.md must include at least one concrete example")

    text_lower = text.lower()
    if "verbatim" not in text_lower or "quote" not in text_lower:
        fail("T20", "factual-red-flags.md must require a verbatim quote")
    if "severity" not in text_lower:
        fail("T20", "factual-red-flags.md must mention severity")
    if "factual red flag" not in text_lower:
        fail("T20", "factual-red-flags.md must name the Factual red flag dimension label")


def validate_bias_framing() -> None:
    if not BIAS_FRAMING_PATH.is_file():
        fail("T22", f"{BIAS_FRAMING_PATH.relative_to(ROOT)} is missing")

    text = BIAS_FRAMING_PATH.read_text(encoding="utf-8")
    if not text.strip():
        fail("T22", f"{BIAS_FRAMING_PATH.relative_to(ROOT)} is empty")

    if not re.search(r"^#{1,6}\s+.*(?:bias|framing).*$", text, flags=re.IGNORECASE | re.MULTILINE):
        fail("T23", "bias-framing.md must contain a bias or framing heading")

    signal_entries = re.findall(r"^\s*(?:[-*]\s+\S|#{2,6}\s+\S)", text, flags=re.MULTILINE)
    if len(signal_entries) < 6:
        fail("T24", "bias-framing.md must enumerate at least six signal entries")

    if not re.search(r"\bexample\b", text, flags=re.IGNORECASE):
        fail("T25", "bias-framing.md must include at least one concrete example")

    text_lower = text.lower()
    if "verbatim" not in text_lower or "quote" not in text_lower:
        fail("T26", "bias-framing.md must require a verbatim quote")
    if "severity" not in text_lower:
        fail("T26", "bias-framing.md must mention severity")
    if "bias & framing" not in text_lower:
        fail("T26", "bias-framing.md must name the Bias & framing dimension label")


def validate_logical_fallacies() -> None:
    if not LOGICAL_FALLACIES_PATH.is_file():
        fail("T28", f"{LOGICAL_FALLACIES_PATH.relative_to(ROOT)} is missing")

    text = LOGICAL_FALLACIES_PATH.read_text(encoding="utf-8")
    if not text.strip():
        fail("T28", f"{LOGICAL_FALLACIES_PATH.relative_to(ROOT)} is empty")

    if not re.search(r"^#{1,6}\s+.*(?:logical|fallac).*$", text, flags=re.IGNORECASE | re.MULTILINE):
        fail("T29", "logical-fallacies.md must contain a logical or fallacy heading")

    signal_entries = re.findall(r"^\s*(?:[-*]\s+\S|#{2,6}\s+\S)", text, flags=re.MULTILINE)
    if len(signal_entries) < 6:
        fail("T30", "logical-fallacies.md must enumerate at least six signal entries")

    if not re.search(r"\bexample\b", text, flags=re.IGNORECASE):
        fail("T31", "logical-fallacies.md must include at least one concrete example")

    text_lower = text.lower()
    if "verbatim" not in text_lower or "quote" not in text_lower:
        fail("T32", "logical-fallacies.md must require a verbatim quote")
    if "severity" not in text_lower:
        fail("T32", "logical-fallacies.md must mention severity")
    if "logical fallacy" not in text_lower:
        fail("T32", "logical-fallacies.md must name the Logical fallacy dimension label")


def validate_clickbait_hype() -> None:
    if not CLICKBAIT_HYPE_PATH.is_file():
        fail("T34", f"{CLICKBAIT_HYPE_PATH.relative_to(ROOT)} is missing")

    text = CLICKBAIT_HYPE_PATH.read_text(encoding="utf-8")
    if not text.strip():
        fail("T34", f"{CLICKBAIT_HYPE_PATH.relative_to(ROOT)} is empty")

    if not re.search(r"^#{1,6}\s+.*(?:clickbait|hype).*$", text, flags=re.IGNORECASE | re.MULTILINE):
        fail("T35", "clickbait-hype.md must contain a clickbait or hype heading")

    signal_entries = re.findall(r"^\s*(?:[-*]\s+\S|#{2,6}\s+\S)", text, flags=re.MULTILINE)
    if len(signal_entries) < 6:
        fail("T36", "clickbait-hype.md must enumerate at least six signal entries")

    if not re.search(r"\bexample\b", text, flags=re.IGNORECASE):
        fail("T37", "clickbait-hype.md must include at least one concrete example")

    text_lower = text.lower()
    if "verbatim" not in text_lower or "quote" not in text_lower:
        fail("T38", "clickbait-hype.md must require a verbatim quote")
    if "severity" not in text_lower:
        fail("T38", "clickbait-hype.md must mention severity")
    if "clickbait / hype" not in text_lower:
        fail("T38", "clickbait-hype.md must name the Clickbait / hype dimension label")


def validate_narrative_manipulation() -> None:
    if not NARRATIVE_MANIPULATION_PATH.is_file():
        fail("T40", f"{NARRATIVE_MANIPULATION_PATH.relative_to(ROOT)} is missing")

    text = NARRATIVE_MANIPULATION_PATH.read_text(encoding="utf-8")
    if not text.strip():
        fail("T40", f"{NARRATIVE_MANIPULATION_PATH.relative_to(ROOT)} is empty")

    if not re.search(r"^#{1,6}\s+.*(?:narrative|manipulation).*$", text, flags=re.IGNORECASE | re.MULTILINE):
        fail("T41", "narrative-manipulation.md must contain a narrative or manipulation heading")

    signal_entries = re.findall(r"^\s*(?:[-*]\s+\S|#{2,6}\s+\S)", text, flags=re.MULTILINE)
    if len(signal_entries) < 6:
        fail("T42", "narrative-manipulation.md must enumerate at least six signal entries")

    if not re.search(r"\bexample\b", text, flags=re.IGNORECASE):
        fail("T43", "narrative-manipulation.md must include at least one concrete example")

    text_lower = text.lower()
    if "verbatim" not in text_lower or "quote" not in text_lower:
        fail("T44", "narrative-manipulation.md must require a verbatim quote")
    if "severity" not in text_lower:
        fail("T44", "narrative-manipulation.md must mention severity")
    if "narrative manipulation" not in text_lower:
        fail("T44", "narrative-manipulation.md must name the Narrative manipulation dimension label")


def validate_findings_format(body: str, render_step: str) -> None:
    if not FINDINGS_FORMAT_PATH.is_file():
        fail("T46", f"{FINDINGS_FORMAT_PATH.relative_to(ROOT)} is missing")

    text = FINDINGS_FORMAT_PATH.read_text(encoding="utf-8")
    if not text.strip():
        fail("T46", f"{FINDINGS_FORMAT_PATH.relative_to(ROOT)} is empty")

    if not re.search(r"^#{1,6}\s+.*(?:finding|evidence|format).*$", text, flags=re.IGNORECASE | re.MULTILINE):
        fail("T47", "findings-format.md must contain a finding, evidence, or format heading")

    text_lower = text.lower()
    for term in ("dimension", "severity", "verbatim", "quote"):
        if term not in text_lower:
            fail("T48", f"findings-format.md must name the {term} entry slot")

    for severity in ("High", "Medium", "Low"):
        if not re.search(
            rf"^\s*(?:[-*]\s*)?(?:\*\*)?{severity}(?:\*\*)?\s*(?:[-:—–]\s+|\s+-\s+)\S+",
            text,
            flags=re.IGNORECASE | re.MULTILINE,
        ):
            fail("T49", f"findings-format.md must define the {severity} severity")

    for label in (
        "factual red flag",
        "bias & framing",
        "logical fallacy",
        "clickbait / hype",
        "narrative manipulation",
    ):
        if label not in text_lower:
            fail("T50", f"findings-format.md must name the {label} dimension label")

    exact_terms = ("exact", "substring", "character-for-character")
    invented_terms = ("paraphrase", "fabricat")
    if "verbatim" not in text_lower or not any(term in text_lower for term in exact_terms):
        fail("T51", "findings-format.md must state that quotes are exact/verbatim")
    if not any(term in text_lower for term in invented_terms):
        fail("T51", "findings-format.md must prohibit paraphrased or fabricated quotes")

    if not re.search(r"\bexample\b", text, flags=re.IGNORECASE):
        fail("T52", "findings-format.md must include a worked example")
    if "references/findings-format.md" not in body:
        fail("T52", "SKILL.md must reference references/findings-format.md")
    if "references/findings-format.md" not in render_step:
        fail("T52", "render step must reference references/findings-format.md")
    if "references/output-format.md" not in render_step:
        fail("T52", "render step must reference references/output-format.md")
    if re.search(r"\b(placeholder|todo)\b", render_step, flags=re.IGNORECASE):
        fail("T52", "render step must not contain placeholder or TODO")

    output_text = OUTPUT_FORMAT_PATH.read_text(encoding="utf-8")
    if "references/findings-format.md" not in output_text:
        fail("T52", "output-format.md Findings section must point to references/findings-format.md")


def validate_scoring(score_step: str) -> None:
    if not SCORING_PATH.is_file():
        fail("T53", f"{SCORING_PATH.relative_to(ROOT)} is missing")

    text = SCORING_PATH.read_text(encoding="utf-8")
    if not text.strip():
        fail("T53", f"{SCORING_PATH.relative_to(ROOT)} is empty")

    if not re.search(r"^#{1,6}\s+.*(?:scor|aggregat|rating).*$", text, flags=re.IGNORECASE | re.MULTILINE):
        fail("T54", "scoring.md must contain a scoring, aggregation, or rating heading")

    # Match each band as a bold token so e.g. **Credible** is not satisfied by
    # the "Credible" substring inside **Not Credible** / **Mostly Credible**.
    for band in ("Credible", "Mostly Credible", "Mixed", "Low Credibility", "Not Credible"):
        if not re.search(rf"\*\*{re.escape(band)}\*\*", text, flags=re.IGNORECASE):
            fail("T55", f"scoring.md must map the {band} band")

    # Match each severity as an explicit input token (`Low` or (Low):) so it is
    # not satisfied by the "Low" substring inside the Low Credibility band.
    for severity in ("High", "Medium", "Low"):
        if not re.search(rf"(?:`{severity}`|\({severity}[):])", text, flags=re.IGNORECASE):
            fail("T56", f"scoring.md must reference {severity} severity")

    text_lower = text.lower()
    if "rationale" not in text_lower:
        fail("T57", "scoring.md must define rationale-synthesis rules")
    if not any(term in text_lower for term in ("consistent", "no new", "not introduce", "only")):
        fail("T57", "scoring.md must state no-new-claims or consistency discipline")
    if "example" not in text_lower:
        fail("T57", "scoring.md must include a worked example")

    if "references/scoring.md" not in score_step:
        fail("T58", "score/aggregate step must reference references/scoring.md")
    if "references/output-format.md" not in score_step:
        fail("T58", "score/aggregate step must reference references/output-format.md")
    if re.search(r"\b(placeholder|todo)\b", score_step, flags=re.IGNORECASE):
        fail("T58", "score/aggregate step must not contain placeholder or TODO")

    output_text = OUTPUT_FORMAT_PATH.read_text(encoding="utf-8")
    if "references/scoring.md" not in output_text:
        fail("T58", "output-format.md rating scale must point to references/scoring.md")


def validate_summary_format(render_step: str) -> None:
    if not SUMMARY_FORMAT_PATH.is_file():
        fail("T59", f"{SUMMARY_FORMAT_PATH.relative_to(ROOT)} is missing")

    text = SUMMARY_FORMAT_PATH.read_text(encoding="utf-8")
    if not text.strip():
        fail("T59", f"{SUMMARY_FORMAT_PATH.relative_to(ROOT)} is empty")

    if not re.search(r"^#{1,6}\s+.*(?:summary|verdict|takeaway).*$", text, flags=re.IGNORECASE | re.MULTILINE):
        fail("T60", "summary-format.md must contain a summary, verdict, or takeaway heading")

    text_lower = text.lower()
    has_breakdown_reference = (
        ("findings" in text_lower and "rationale" in text_lower)
        or "detailed breakdown" in text_lower
    )
    if not has_breakdown_reference or not any(term in text_lower for term in ("top", "above", "first")):
        fail("T61", "summary-format.md must state that the summary sits at the top above the detailed breakdown")

    if not any(term in text_lower for term in ("plain", "non-expert", "jargon", "lay")):
        fail("T62", "summary-format.md must require plain, non-expert language")

    if not any(term in text_lower for term in ("consistent", "no new", "not introduce")):
        fail("T63", "summary-format.md must state the consistency or no-new-claims rule")
    if "example" not in text_lower:
        fail("T63", "summary-format.md must include a worked example")

    for reference in (
        "references/summary-format.md",
        "references/output-format.md",
        "references/findings-format.md",
    ):
        if reference not in render_step:
            fail("T64", f"render step must reference {reference}")
    if re.search(r"\b(placeholder|todo)\b", render_step, flags=re.IGNORECASE):
        fail("T64", "render step must not contain placeholder or TODO")

    output_text = OUTPUT_FORMAT_PATH.read_text(encoding="utf-8")
    if "references/summary-format.md" not in output_text:
        fail("T64", "output-format.md must point to references/summary-format.md")
    if not re.search(r"\*\*Bottom line:\*\*", output_text, flags=re.IGNORECASE):
        fail("T64", "output-format.md Verdict section must include a plain-language bottom-line line")


def main() -> int:
    frontmatter, body = parse_skill()

    if frontmatter.get("name") != "fake-news-detector":
        fail("T3", "frontmatter name must equal fake-news-detector")

    description = frontmatter.get("description")
    if not isinstance(description, str) or not description.strip():
        fail("T4", "frontmatter description must be a non-empty string")

    purpose_terms = ("credibility", "misinformation", "fake news", "bias")
    input_terms = ("article", "headline", "post", "text")
    description_lower = description.lower()
    if not any(term in description_lower for term in purpose_terms):
        fail("T5", "description must mention credibility, misinformation, fake news, or bias")
    if not any(term in description_lower for term in input_terms):
        fail("T5", "description must mention article, headline, post, or text input")

    if not re.search(r"^#{1,6}\s+.*input.*$", body, flags=re.IGNORECASE | re.MULTILINE):
        fail("T6", "body must contain an input-related heading")

    body_lower = body.lower()
    if "untrusted" not in body_lower or "data" not in body_lower:
        fail("T7", "body must frame analyzed content as untrusted data")

    if not re.search(r"^#{1,6}\s+.*workflow.*$", body, flags=re.IGNORECASE | re.MULTILINE):
        fail("T8", "body must contain a Workflow heading")

    validate_output_format()
    validate_factual_red_flags()
    validate_bias_framing()
    validate_logical_fallacies()
    validate_clickbait_hype()
    validate_narrative_manipulation()

    if "references/output-format.md" not in body:
        fail("T15", "SKILL.md must reference references/output-format.md")

    detection_step = require_step(body, 2)
    score_step = require_step(body, 3)
    render_step = require_step(body, 4)
    validate_findings_format(body, render_step)
    validate_scoring(score_step)
    validate_summary_format(render_step)
    if "references/factual-red-flags.md" not in detection_step:
        fail("T21", "detection step must reference references/factual-red-flags.md")
    if "references/bias-framing.md" not in detection_step:
        fail("T27", "detection step must reference references/bias-framing.md")
    if "references/logical-fallacies.md" not in detection_step:
        fail("T33", "detection step must reference references/logical-fallacies.md")
    for reference in (
        "references/factual-red-flags.md",
        "references/bias-framing.md",
        "references/logical-fallacies.md",
        "references/clickbait-hype.md",
    ):
        if reference not in detection_step:
            fail("T39", f"detection step must reference {reference}")
    if "references/narrative-manipulation.md" not in detection_step:
        fail("T45", "detection step must reference references/narrative-manipulation.md")
    if re.search(r"\b(placeholder|todo)\b", detection_step, flags=re.IGNORECASE):
        fail("T45", "detection step must not contain a placeholder or TODO for remaining dimensions")
    for step_name, step_text in (("score/aggregate", score_step), ("render-verdict", render_step)):
        if re.search(r"\b(placeholder|todo)\b", step_text, flags=re.IGNORECASE):
            fail("T15", f"{step_name} step must not contain placeholder or TODO")
        if "references/output-format.md" not in step_text:
            fail("T15", f"{step_name} step must reference references/output-format.md")

    print("fake-news-detector skill scaffold validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
