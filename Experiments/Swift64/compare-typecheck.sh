#!/usr/bin/env bash
set -euo pipefail

# Compare only explicitly selected matching host/SDK pairs. This does not
# download toolchains and does not claim timings are comparable across machines.
# Example:
# SWIFT63=swift SWIFTC63=swiftc SDK63=swift-6.3.3-RELEASE_wasm \
# SWIFT64=/path/swift SWIFTC64=/path/swiftc SDK64=swift-6.4-... ./compare-typecheck.sh
for name in SWIFT63 SWIFTC63 SDK63 SWIFT64 SWIFTC64 SDK64; do
  test -n "${!name:-}" || { echo "missing $name" >&2; exit 64; }
done
root="${1:-../..}"
for version in 63 64; do
  if [ "$version" = 63 ]; then
    swift_bin="$SWIFT63"; swiftc_bin="$SWIFTC63"; sdk="$SDK63"
  else
    swift_bin="$SWIFT64"; swiftc_bin="$SWIFTC64"; sdk="$SDK64"
  fi
  echo "== Swift $version =="
  "$swift_bin" --version
  "$swiftc_bin" --version
  "$swift_bin" sdk list | grep -F -x "$sdk" >/dev/null
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/swiftwui-typecheck-$version.XXXXXX")"
  trap 'rm -rf "$scratch"' EXIT
  /usr/bin/time -p env PATH="$(dirname "$swiftc_bin"):$PATH" SWIFT_EXEC="$swiftc_bin" \
    "$swift_bin" build --package-path "$root" --scratch-path "$scratch" --target SwiftWUI
  rm -rf "$scratch"
done
