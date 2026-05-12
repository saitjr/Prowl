#!/usr/bin/env bash
set -euo pipefail

if command -v xcsift >/dev/null 2>&1; then
  exec xcsift "$@"
fi

if command -v mise >/dev/null 2>&1 && mise which xcsift >/dev/null 2>&1; then
  exec mise exec github:ldomaradzki/xcsift@1.1.3 -- xcsift "$@"
fi

echo "warning: xcsift unavailable; streaming raw xcodebuild output" >&2
exec cat
