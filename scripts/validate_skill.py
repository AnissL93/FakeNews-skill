#!/usr/bin/env python3
"""Validate the fake-news-detector skill scaffold."""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
SKILL_PATH = ROOT / ".claude" / "skills" / "fake-news-detector" / "SKILL.md"


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

    print("fake-news-detector skill scaffold validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
