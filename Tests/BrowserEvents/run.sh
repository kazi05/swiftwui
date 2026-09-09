#!/usr/bin/env bash
# Build the WASM fixture and run the existing repository Playwright harness.
set -euo pipefail

fixture_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$fixture_dir/../.." && pwd)"
harness_dir="$repo_dir/Sites/Tutorial/tools/screenshots"
port="${SWIFTWUI_BROWSER_PORT:-4175}"
sdk="${SWIFTWUI_BROWSER_SDK:-swift-6.3.3-RELEASE_wasm}"

# SwiftPM's nested plugin build can otherwise fall back to Xcode's compiler,
# which has no wasm target. Derive both compilers from the selected Swift SDK host.
compiler_dir="$(swiftc -print-target-info | node -e '
  const fs = require("node:fs"), path = require("node:path");
  const info = JSON.parse(fs.readFileSync(0, "utf8"));
  process.stdout.write(path.resolve(info.paths.runtimeResourcePath, "../../bin"));
')"
export SWIFT_EXEC="$compiler_dir/swiftc"
export CC="$compiler_dir/clang"

(cd "$fixture_dir" && swift package --swift-sdk "$sdk" js -c debug)
# This is the existing WASI dependency emitted by JavaScriptKit's packager.
npm install --ignore-scripts --no-audit --no-fund \
  --prefix "$fixture_dir/.build/plugins/PackageToJS/outputs/Package"
if [[ ! -f "$harness_dir/node_modules/@playwright/test/cli.js" ]]; then
  npm ci --ignore-scripts --no-audit --no-fund --prefix "$harness_dir"
fi

python3 "$fixture_dir/server.py" --port "$port" &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' EXIT
for _ in {1..60}; do
  kill -0 "$server_pid" 2>/dev/null || { echo "Fixture server exited" >&2; exit 1; }
  if curl -fsS "http://127.0.0.1:$port/" >/dev/null 2>&1; then break; fi
  sleep 0.25
done

(cd "$harness_dir" && BROWSER_EVENTS_BASE_URL="http://127.0.0.1:$port" \
  node node_modules/@playwright/test/cli.js test --config browser-events.config.mjs "$@")
