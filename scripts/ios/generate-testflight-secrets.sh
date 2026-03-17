#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Generate TestFlight/App Store Connect API secrets in KEY=value format.

Usage:
  scripts/ios/generate-testflight-secrets.sh \
    --issuer-id <ISSUER_ID_UUID> \
    --key-file <AuthKey_XXXXXXXXXX.p8> \
    [--key-id <KEY_ID>] \
    [--output <OUTPUT_FILE>]

Output keys:
  APPLE_API_ISSUER_ID
  APPLE_API_KEY_ID
  APPLE_API_PRIVATE_KEY_BASE64
USAGE
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

issuer_id=""
key_file=""
key_id=""
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issuer-id)
      issuer_id="${2:-}"
      shift 2
      ;;
    --key-file)
      key_file="${2:-}"
      shift 2
      ;;
    --key-id)
      key_id="${2:-}"
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

[[ -n "$issuer_id" ]] || fail "--issuer-id is required"
[[ -n "$key_file" ]] || fail "--key-file is required"
[[ -f "$key_file" ]] || fail "Key file not found: $key_file"

if [[ -z "$key_id" ]]; then
  base_name="$(basename "$key_file")"
  if [[ "$base_name" =~ ^AuthKey_([A-Za-z0-9]+)\.p8$ ]]; then
    key_id="${BASH_REMATCH[1]}"
  else
    fail "Unable to infer key id from filename '$base_name'. Pass --key-id explicitly."
  fi
fi

key_b64="$(base64 < "$key_file" | tr -d '\n')"
[[ -n "$key_b64" ]] || fail "Failed to base64-encode key file"

payload=$(cat <<PAYLOAD
APPLE_API_ISSUER_ID=$issuer_id
APPLE_API_KEY_ID=$key_id
APPLE_API_PRIVATE_KEY_BASE64=$key_b64
PAYLOAD
)

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$payload" > "$output_file"
  echo "Wrote $output_file"
else
  printf '%s\n' "$payload"
fi
