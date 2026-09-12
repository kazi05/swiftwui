#!/usr/bin/env bash

set -euo pipefail

# Keep the native compiler and the WebAssembly SDK on the same Swift release.
# Source: https://www.swift.org/install/linux/ubuntu/24_04/
readonly swift_version="6.3.3"
readonly swift_release="swift-${swift_version}-RELEASE"
readonly swift_archive="${swift_release}-ubuntu24.04.tar.gz"
readonly swift_base_url="https://download.swift.org/swift-${swift_version}-release/ubuntu2404/${swift_release}"
readonly swift_signing_fingerprint="52BB7E3DE28A71BE22EC05FFEF80A866B47A981F"

: "${RUNNER_TEMP:?RUNNER_TEMP must be set by GitHub Actions}"
: "${GITHUB_PATH:?GITHUB_PATH must be set by GitHub Actions}"

readonly download_dir="${RUNNER_TEMP}/${swift_release}-download"
readonly install_dir="${RUNNER_TEMP}/${swift_release}"
readonly keyring_dir="${RUNNER_TEMP}/${swift_release}-gnupg"
readonly archive_path="${download_dir}/${swift_archive}"
readonly signature_path="${archive_path}.sig"
readonly keys_path="${download_dir}/swift-signing-keys.asc"
readonly verification_status="${download_dir}/verification.status"

mkdir -p "$download_dir" "$install_dir" "$keyring_dir"
chmod 700 "$keyring_dir"

curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
  "${swift_base_url}/${swift_archive}" \
  --output "$archive_path"
curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
  "${swift_base_url}/${swift_archive}.sig" \
  --output "$signature_path"
curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
  "https://swift.org/keys/all-keys.asc" \
  --output "$keys_path"

gpg --homedir "$keyring_dir" --batch --quiet --import "$keys_path"

imported_fingerprint="$({
  gpg --homedir "$keyring_dir" --batch --with-colons \
    --fingerprint "$swift_signing_fingerprint"
} | awk -F: '$1 == "fpr" { print $10; exit }')"

if [[ "$imported_fingerprint" != "$swift_signing_fingerprint" ]]; then
  echo "Expected Swift signing key ${swift_signing_fingerprint}, got ${imported_fingerprint:-none}" >&2
  exit 1
fi

gpg --homedir "$keyring_dir" --batch --status-fd 1 \
  --verify "$signature_path" "$archive_path" \
  >"$verification_status"

verified_fingerprint="$(awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" { print $3; exit }' "$verification_status")"
if [[ "$verified_fingerprint" != "$swift_signing_fingerprint" ]]; then
  echo "Swift archive was signed by unexpected key ${verified_fingerprint:-none}" >&2
  exit 1
fi

tar --extract --gzip --file "$archive_path" \
  --directory "$install_dir" \
  --strip-components 1

version_output="$("${install_dir}/usr/bin/swift" --version)"
if [[ "$version_output" != *"Swift version ${swift_version} (${swift_release})"* ]]; then
  echo "Installed toolchain does not match ${swift_release}:" >&2
  echo "$version_output" >&2
  exit 1
fi

echo "${install_dir}/usr/bin" >>"$GITHUB_PATH"
echo "$version_output"
