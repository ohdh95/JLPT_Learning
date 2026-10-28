#!/bin/sh
set -eu
JLPT_PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$JLPT_PROJECT_DIR/tool/run_emulator.py" "$@"
