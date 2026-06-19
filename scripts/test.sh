#!/usr/bin/env bash
# Project tests.
set -euo pipefail
python3 scripts/validate_skill.py
python3 -c "import ast; ast.parse(open('scripts/validate_skill.py').read())"
python3 -c "import ast,sys; t=ast.parse(open('scripts/validate_skill.py').read()); missing=[n.name for n in t.body if isinstance(n,ast.FunctionDef) and not ast.get_docstring(n)]; print(missing); sys.exit(1 if missing else 0)"

for term in \
  "Factual red flag" \
  "Bias & framing" \
  "Logical fallacy" \
  "Clickbait / hype" \
  "Narrative manipulation" \
  "Credible" \
  "Mostly Credible" \
  "Mixed" \
  "Low Credibility" \
  "Not Credible"
do
  grep -F "$term" README.md >/dev/null
done

grep -iE 'verbatim|quote' README.md >/dev/null
grep -iE 'untrusted|prompt[- ]injection' README.md >/dev/null
grep -F '## Verdict' README.md >/dev/null
grep -F '## Findings' README.md >/dev/null
test -f CHANGELOG.md
for issue in "#11" "#12" "#13" "#14" "#15" "#16"
do
  grep -F "$issue" CHANGELOG.md >/dev/null
done
