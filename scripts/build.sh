#!/usr/bin/env bash
# Dependency / toolchain setup. Runs BEFORE scripts/test.sh in CI and the pipeline.
# Install everything the tests need here (e.g. pip install -r requirements.txt, npm ci).
set -euo pipefail
python3 -m pip install --quiet pyyaml
