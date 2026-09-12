#!/usr/bin/env bash
set -euo pipefail

# Usage: SWIFT64=/path/to/swift SWIFTC64=/path/to/swiftc ./run-se0506.sh
# The pair is explicit so a shell PATH that mixes Xcode and swiftly cannot turn
# a language experiment into a misleading result.
swift_bin="${SWIFT64:?set SWIFT64 to the matching Swift 6.4 executable}"
swiftc_bin="${SWIFTC64:?set SWIFTC64 to the matching Swift 6.4 compiler}"
swift_version="$("$swift_bin" --version)"
swiftc_version="$("$swiftc_bin" --version)"
printf '%s\n%s\n' "$swift_version" "$swiftc_version"
version_pattern='Swift version (6\.4([.][0-9]+)?)([ -]|$)'
[[ "$swift_version" =~ $version_pattern ]] || { echo 'Swift 6.4 host required' >&2; exit 1; }
host_version="${BASH_REMATCH[1]}"
[[ "$swiftc_version" =~ $version_pattern && "${BASH_REMATCH[1]}" == "$host_version" ]] || { echo 'Matching Swift 6.4 compiler required' >&2; exit 1; }
scratch="$(mktemp -d "${TMPDIR:-/tmp}/swiftwui-se0506.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
"$swiftc_bin" -swift-version 6 -parse-as-library \
  "$(dirname "$0")/ContinuousObservation.swift" -o "$scratch/se0506"
"$scratch/se0506"
