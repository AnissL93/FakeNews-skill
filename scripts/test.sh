#!/usr/bin/env bash
# Project tests.
set -euo pipefail
python3 scripts/validate_skill.py
python3 -c "import ast; ast.parse(open('scripts/validate_skill.py').read())"
python3 -c "import ast,sys; t=ast.parse(open('scripts/validate_skill.py').read()); missing=[n.name for n in t.body if isinstance(n,ast.FunctionDef) and not ast.get_docstring(n)]; print(missing); sys.exit(1 if missing else 0)"

# README names all five detection dimensions and all five rating bands.
for term in "Factual red flag" "Bias & framing" "Logical fallacy" "Clickbait / hype" "Narrative manipulation" "Credible" "Mostly Credible" "Mixed" "Low Credibility" "Not Credible"; do
  grep -qF "$term" README.md || { echo "README.md missing: $term"; exit 1; }
done

# README mentions verbatim-quote evidence and prompt-injection / untrusted-data handling.
grep -qiE 'verbatim|quote' README.md || { echo "README.md missing verbatim/quote mention"; exit 1; }
grep -qiE 'untrusted|prompt[- ]injection' README.md || { echo "README.md missing untrusted/prompt-injection mention"; exit 1; }

# README contains the Verdict / Findings sample-output block.
grep -qF '## Verdict' README.md || { echo "README.md missing '## Verdict' block"; exit 1; }
grep -qF '## Findings' README.md || { echo "README.md missing '## Findings' block"; exit 1; }

# CHANGELOG references each issue #11 through #16.
for n in 11 12 13 14 15 16; do
  grep -qE "#$n" CHANGELOG.md || { echo "CHANGELOG.md missing reference to #$n"; exit 1; }
done
