#!/bin/zsh
set -eu
cd "${0:A:h}/.."
check_dir=$(mktemp -d /tmp/codex-window-checks.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library \
  codex-usage-swift/WindowHeightLimit.swift \
  Tests/WindowSizingChecks.swift \
  -module-cache-path /tmp/codex-usage-module-cache \
  -o "$check_dir/window-checks"
"$check_dir/window-checks"
