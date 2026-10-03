#!/bin/zsh
set -eu
cd "${0:A:h}/.."
check_dir=$(mktemp -d /tmp/codex-usage-checks.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library \
  codex-usage-swift/UsageModels.swift \
  codex-usage-swift/CodexClient.swift \
  Tests/UsageChecks.swift \
  -module-cache-path /tmp/codex-usage-module-cache \
  -o "$check_dir/usage-checks"
"$check_dir/usage-checks" --fake "$PWD/Tests/fake-codex.py" "$@"
