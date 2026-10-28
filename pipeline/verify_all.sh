#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter analyze
flutter test
python3 -m unittest discover -s pipeline/tests -v
python3 pipeline/self_test.py
python3 pipeline/audit_report.py --db assets/content.sqlite --outdir reports/audit
python3 pipeline/release_gate.py --db assets/content.sqlite
flutter build apk --debug
