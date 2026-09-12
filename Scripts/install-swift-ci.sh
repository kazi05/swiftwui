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
readonly minimum_archive_bytes=500000000

mkdir -p "$download_dir" "$install_dir" "$keyring_dir"
chmod 700 "$keyring_dir"

echo "Downloading Swift ${swift_version} release signature"
curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
  "${swift_base_url}/${swift_archive}.sig" \
  --output "$signature_path"

if ! gpg --batch --list-packets "$signature_path" >/dev/null 2>&1; then
  echo "Downloaded Swift signature is not valid OpenPGP data" >&2
  exit 1
fi

# Pin the exact Swift 6.x release key instead of relying on a mutable keyserver
# response. Source: https://www.swift.org/keys/all-keys.asc. The fingerprint
# below is still checked after import and verification.
cat >"$keys_path" <<'SWIFT_SIGNING_KEY'
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBGbolYEBEADEvoijjZaq+5hLyiOHMns6+i/1mxczO5g9ZuXANYMI5uKXNgED
dWoJRJV1DKwY+1f9oBdcEctD0um4LY6346p38SJOurk/zRqlEx25sAq0bbOn0epE
BrOkHnmgBp+C5gWgrk+gKGjOXw63m2ipKp5joxP7QI7iplb7LRHnqOWqVFPF6c+A
y5zq7/FFfECwHYdkS3IV8uYG0qPmKDYoJgqCbySGzbHTiawFt8OJS5xYqzhXrClh
KMJf6orq8gNF4eBwa6FkyJFyPf/s8mbW3wREirL9DFinurMK68pUA7SDxLsegGgt
2PVse5o+1TVcKTDTCV0v5gmiQyXIUzvB87GaJLVIEIwYb08jtSBMvVLdVIpWv6RJ
bi7za2LvfaCBcpSAbqCtoq/lk9NYrXs8uiENxW0srIWoKoe6Gfvz0XvJEjJPIMNH
cy/42Nt3kgn6V3lHTioTPhxyEJ8AZ+s7yIeVR5fYuxdlVwe6zhiwvGtjWLmjTZBY
RbXayDV3ekNL3rEQ4qhXrvcmW0/v7n+vzf6a7Wog6R4pHr67BafM3v9M6jpu4Lqk
mLyXU/lX1+VTzKz7vDCz8CXafYUP8wFYGGW73xzd6Kho8vya1E4WNg+UPnYcu2SV
TkQe50I2Ik95QEAEdG3DJrLiGuLwH170KgeMYpWffNLtUNH1oCkh1lj8jQARAQAB
tEVTd2lmdCA2LnggUmVsZWFzZSBTaWduaW5nIEtleSA8c3dpZnQtaW5mcmFzdHJ1
Y3R1cmVAZm9ydW1zLnN3aWZ0Lm9yZz6JAj0EEwEKACcFAmbolYECGwMFCQPCZwAF
CwkIBwMFFQoJCAsFFgIDAQACHgECF4AACgkQ74CoZrR6mB/DIhAAnSHnGfRpr/0A
98dWa2uM2tt4oGT1+SN+va544/vu6CAc9jhvS871GvHe25B5HL5S6MDF3dim3oQe
zIGaIx3DUhbb0/JLeayL3NfhbCed5DX0W1XIQtksjYuHnvBRD+zrhcTQKqumR+LU
NVOh6l4o2Ko+aAYc8mIm+HufryRKJSWup1ZnExEdcZZEzyY4kT0H1fxAIWWU3NI1
LDtq1O0Wl5CTUHU7mI/h2eWrxFDg4SmfV9dv4uBXyvxherHEhImJXceQ4ZkxvYGF
amXjlNzIr8c6y/IE8Q775nkfG5+4Gt+bGIJqxeSzfc4wq+txMa85TtRpgSthgqFi
+yQx5qghs3y8Pqj3kDatJB41oQZ221WbBRc2uvFDMWUaOtJ/pRymCN54FUwxUm6U
aM4VTWbGw0es1QRO+Px25Thoh8a5a3Fu0s9fa1sDJOUYSc7vfyRUfqNOVv5g8rnS
sPTmOGGjrjxWHA0oL7B5hxCR+/jBhw+6mLu18qwGI7YpgyZYSzowPY+LrMm/J973
SyUtlCb2o42WhDR9FsX0AGvLhZpxy4Q7br7Pa2RXwmWEaxZik0iQ2Sg4pEvL5tVd
aFIUvVsFlayfXSBCZVjH0uyh0Vkk1ERZpSmxkRWgzp5MRIfkP5eh9009uhEUmxHV
Yih/un915S6ObH32x1IbJfi0cGK1NUA=
=sWSN
-----END PGP PUBLIC KEY BLOCK-----
SWIFT_SIGNING_KEY

gpg --homedir "$keyring_dir" --batch --quiet --import "$keys_path"

imported_fingerprint="$({
  gpg --homedir "$keyring_dir" --batch --with-colons \
    --fingerprint "$swift_signing_fingerprint"
} | awk -F: '$1 == "fpr" { print $10; exit }')"

if [[ "$imported_fingerprint" != "$swift_signing_fingerprint" ]]; then
  echo "Expected Swift signing key ${swift_signing_fingerprint}, got ${imported_fingerprint:-none}" >&2
  exit 1
fi

echo "Downloading Swift ${swift_version} toolchain"
curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
  "${swift_base_url}/${swift_archive}" \
  --output "$archive_path"

archive_size="$(stat --format='%s' "$archive_path")"
archive_magic="$(od -An -tx1 -N2 "$archive_path" | tr -d '[:space:]')"
if [[ "$archive_size" -lt "$minimum_archive_bytes" || "$archive_magic" != "1f8b" ]]; then
  echo "Downloaded Swift archive is invalid: size=${archive_size}, gzip_magic=${archive_magic:-none}" >&2
  exit 1
fi

echo "Verifying Swift ${swift_version} toolchain signature"
gpg --homedir "$keyring_dir" --batch --status-fd 1 \
  --verify "$signature_path" "$archive_path" \
  >"$verification_status"

verified_fingerprint="$(awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" { print $3; exit }' "$verification_status")"
if [[ "$verified_fingerprint" != "$swift_signing_fingerprint" ]]; then
  echo "Swift archive was signed by unexpected key ${verified_fingerprint:-none}" >&2
  exit 1
fi

echo "Extracting Swift ${swift_version} toolchain"
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
