#!/bin/bash
# Assemble the full tutorial site into dist/. Run from Sites/Tutorial.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
swift run --package-path "$REPO" swiftwui build --out dist
mkdir -p dist/assets && cp -R Assets/. dist/assets/
swift run --package-path "$REPO" swiftwui ssg --out dist
echo "site assembled: dist/ — preview with: swift run --package-path $REPO swiftwui serve dist"
