#!/usr/bin/env bash
set -euo pipefail
# Regenerate golden baselines. Goldens are Linux-canonical (host AA differs on
# macOS); refuse to regen elsewhere so a mac dev can't poison the baseline.
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Goldens must be regenerated on Linux. Use Docker:" >&2
  echo "  docker run --rm -v \"\$PWD\":/w -w /w ghcr.io/cirruslabs/flutter:3.47.2 \\" >&2
  echo "    flutter test test/goldens --tags golden --update-goldens" >&2
  exit 2
fi
TZ=UTC flutter test test/goldens --tags golden --update-goldens "$@"
