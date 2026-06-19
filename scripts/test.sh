#!/usr/bin/env bash
# Project tests.
set -euo pipefail
python3 scripts/validate_skill.py
python3 -c "import ast; ast.parse(open('scripts/validate_skill.py').read())"
python3 -c "import ast,sys; t=ast.parse(open('scripts/validate_skill.py').read()); missing=[n.name for n in t.body if isinstance(n,ast.FunctionDef) and not ast.get_docstring(n)]; print(missing); sys.exit(1 if missing else 0)"
