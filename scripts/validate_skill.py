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
    if not re.search(r"\b(placeholder|todo)\b", body, flags=re.IGNORECASE):
        fail("T8", "body must contain an explicit placeholder or TODO marker")

    validate_output_format()
    validate_factual_red_flags()
    validate_bias_framing()
    validate_logical_fallacies()

    if "references/output-format.md" not in body:
        fail("T15", "SKILL.md must reference references/output-format.md")

    detection_step = require_step(body, 2)
    score_step = require_step(body, 3)
    render_step = require_step(body, 4)
    if not re.search(r"\b(placeholder|todo)\b", detection_step, flags=re.IGNORECASE):
        fail("T15", "detection-dimensions step must keep its placeholder for later issues")
    if "references/factual-red-flags.md" not in detection_step:
        fail("T21", "detection step must reference references/factual-red-flags.md")
    if not re.search(r"\b(placeholder|todo)\b", detection_step, flags=re.IGNORECASE):
        fail("T21", "detection step must keep a placeholder or TODO for remaining dimensions")
    if "references/bias-framing.md" not in detection_step:
        fail("T27", "detection step must reference references/bias-framing.md")
    if not re.search(r"\b(placeholder|todo)\b", detection_step, flags=re.IGNORECASE):
        fail("T27", "detection step must keep a placeholder or TODO for remaining dimensions")
    if "references/logical-fallacies.md" not in detection_step:
        fail("T33", "detection step must reference references/logical-fallacies.md")
    if not re.search(r"\b(placeholder|todo)\b", detection_step, flags=re.IGNORECASE):
        fail("T33", "detection step must keep a placeholder or TODO for remaining dimensions")
    for step_name, step_text in (("score/aggregate", score_step), ("render-verdict", render_step)):
        if re.search(r"\b(placeholder|todo)\b", step_text, flags=re.IGNORECASE):
            fail("T15", f"{step_name} step must not contain placeholder or TODO")
        if "references/output-format.md" not in step_text:
            fail("T15", f"{step_name} step must reference references/output-format.md")

    print("fake-news-detector skill scaffold validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
