#!/bin/bash
# run-smoke.sh — build the full site, serve it, run the smoke suite.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SITE="$HERE/../.."
REPO="$SITE/../.."
PORT=4174

(cd "$SITE" && ./build-site.sh)
(cd "$SITE" && swift run --package-path "$REPO" swiftwui serve dist --port $PORT) &
SERVER=$!
# SwiftPM runs the listener in its own process group — kill by port too,
# or reruns die with "port already in use".
trap 'kill $SERVER 2>/dev/null; lsof -ti :$PORT | xargs kill 2>/dev/null; true' EXIT
for i in $(seq 1 60); do curl -sf "http://localhost:$PORT/" >/dev/null && break; sleep 0.5; done
(cd "$HERE" && SMOKE_BASE_URL="http://localhost:$PORT" npx playwright test)
