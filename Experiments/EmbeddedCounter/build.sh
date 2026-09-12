#!/usr/bin/env bash
set -euo pipefail

# Uses an isolated scratch path so this experiment never races the repository's
# native build directory. `swift sdk list` must show the requested SDK first.
sdk="${SWIFTWUI_EMBEDDED_SDK:-swift-6.3.3-RELEASE_wasm-embedded}"
regular_sdk="${SWIFTWUI_WASM_SDK:-swift-6.3.3-RELEASE_wasm}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/swiftwui-embedded.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
cd "$script_dir"
swift sdk list | grep -F -x "$sdk" >/dev/null
swift sdk list | grep -F -x "$regular_sdk" >/dev/null
regular="$scratch/regular"
embedded="$scratch/embedded"
exports=( -Xlinker --export=counterIncrement -Xlinker --export=counterReset -Xlinker --export=counterValue )
swift build --swift-sdk "$regular_sdk" --scratch-path "$regular" -c release "${exports[@]}"
swift build --swift-sdk "$sdk" --scratch-path "$embedded" -c release \
  -Xswiftc -enable-experimental-feature -Xswiftc Embedded "${exports[@]}"
for profile in regular embedded; do
  artifact="$(find "$scratch/$profile" -type f -name 'EmbeddedCounter.wasm' -print -quit)"
  test -n "$artifact"
  echo "== $profile =="
  wc -c "$artifact"
  shasum -a 256 "$artifact"
  node --experimental-wasi-unstable-preview1 "$script_dir/smoke.mjs" "$artifact"
done
