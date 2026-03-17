#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Generate iOS signing secrets in KEY=value format.

Usage:
  scripts/ios/generate-ios-signing-secrets.sh \
    --team-id <TEAM_ID> \
    --p12-file <CERTIFICATE.p12> \
    --p12-password <PASSWORD> \
    --profile-file <PROFILE.mobileprovision> \
    [--keychain-password <PASSWORD>] \
    [--output <OUTPUT_FILE>]

Output keys:
  IOS_TEAM_ID
  IOS_DISTRIBUTION_CERTIFICATE_BASE64
  IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
  IOS_PROVISIONING_PROFILE_BASE64
  IOS_KEYCHAIN_PASSWORD
USAGE
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

random_secret() {
  # Portable secret generator for CI keychain password fallback.
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 48 | tr -d '\n' | cut -c1-32
  else
    date +%s | sha256sum | cut -c1-32
  fi
}

team_id=""
p12_file=""
p12_password=""
profile_file=""
keychain_password=""
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id)
      team_id="${2:-}"
      shift 2
      ;;
    --p12-file)
      p12_file="${2:-}"
      shift 2
      ;;
    --p12-password)
      p12_password="${2:-}"
      shift 2
      ;;
    --profile-file)
      profile_file="${2:-}"
      shift 2
      ;;
    --keychain-password)
      keychain_password="${2:-}"
      shift 2
      ;;
    --output)
      output_file="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$team_id" ]] || fail "--team-id is required"
[[ -n "$p12_file" ]] || fail "--p12-file is required"
[[ -n "$p12_password" ]] || fail "--p12-password is required"
[[ -n "$profile_file" ]] || fail "--profile-file is required"
[[ -f "$p12_file" ]] || fail "p12 file not found: $p12_file"
[[ -f "$profile_file" ]] || fail "Provisioning profile file not found: $profile_file"

if [[ -z "$keychain_password" ]]; then
  keychain_password="$(random_secret)"
fi

p12_b64="$(base64 < "$p12_file" | tr -d '\n')"
profile_b64="$(base64 < "$profile_file" | tr -d '\n')"

[[ -n "$p12_b64" ]] || fail "Failed to base64-encode p12 file"
[[ -n "$profile_b64" ]] || fail "Failed to base64-encode provisioning profile"

payload=$(cat <<PAYLOAD
IOS_TEAM_ID=$team_id
IOS_DISTRIBUTION_CERTIFICATE_BASE64=$p12_b64
IOS_DISTRIBUTION_CERTIFICATE_PASSWORD=$p12_password
IOS_PROVISIONING_PROFILE_BASE64=$profile_b64
IOS_KEYCHAIN_PASSWORD=$keychain_password
PAYLOAD
)

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$payload" > "$output_file"
  echo "Wrote $output_file"
else
  printf '%s\n' "$payload"
fi
