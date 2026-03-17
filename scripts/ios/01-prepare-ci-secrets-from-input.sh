#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Generate all GitHub iOS/TestFlight CI secrets from scripts/ios/input into scripts/ios/output.

Usage:
  scripts/ios/prepare-ci-secrets-from-input.sh \
    [--input-dir <INPUT_DIR>] \
    [--output-dir <OUTPUT_DIR>] \
    [--env-file <ENV_FILE>] \
    [--key-file <P8_FILE>] \
    [--p12-file <P12_FILE>] \
    [--profile-file <MOBILEPROVISION_FILE>]

Defaults:
  INPUT_DIR  = scripts/ios/input
  OUTPUT_DIR = scripts/ios/output
  ENV_FILE   = <INPUT_DIR>/vars.env

Required env vars in vars.env:
  APPLE_API_ISSUER_ID
  IOS_TEAM_ID
  IOS_DISTRIBUTION_CERTIFICATE_PASSWORD

Optional env vars in vars.env:
  APPLE_API_KEY_ID
  IOS_KEYCHAIN_PASSWORD

Output files:
  testflight-secrets.env
  ios-signing-secrets.env
  github-secrets.env
  apply-secrets-with-gh.sh
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

load_env_file() {
  local file="$1"
  local line=""
  local key=""
  local value=""
  local lineno=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    line="${line%$'\r'}"

    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"

      # Allow surrounding quotes for convenience while preserving special chars.
      if [[ "$value" =~ ^\"(.*)\"$ ]]; then
        value="${BASH_REMATCH[1]}"
      elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
        value="${BASH_REMATCH[1]}"
      fi

      printf -v "$key" '%s' "$value"
      export "$key"
    else
      fail "Invalid line ${lineno} in ${file}. Expected KEY=value"
    fi
  done < "$file"
}

find_single_file() {
  local dir="$1"
  local pattern="$2"
  local label="$3"
  local -a files=()

  while IFS= read -r file; do
    files+=("$file")
  done < <(find "$dir" -maxdepth 1 -type f -name "$pattern" | sort)

  if [[ ${#files[@]} -eq 0 ]]; then
    fail "No ${label} found in ${dir} (pattern: ${pattern})"
  fi

  if [[ ${#files[@]} -gt 1 ]]; then
    fail "Multiple ${label} files found in ${dir}. Pass explicit --${label}-file."
  fi

  printf '%s\n' "${files[0]}"
}

find_optional_file() {
  local dir="$1"
  local pattern="$2"
  local -a files=()

  while IFS= read -r file; do
    files+=("$file")
  done < <(find "$dir" -maxdepth 1 -type f -name "$pattern" | sort)

  if [[ ${#files[@]} -gt 1 ]]; then
    fail "Multiple files matching '${pattern}' found in ${dir}. Remove extras or pass explicit path."
  fi

  printf '%s\n' "${files[0]:-}"
}

build_p12() {
  local priv_key="$1"
  local cert_source="$2"
  local password="$3"
  local output="$4"
  local tmp_pem=""

  # Convert DER .cer to PEM if needed.
  if [[ "$cert_source" == *.cer ]]; then
    tmp_pem="$(mktemp --suffix=.pem)"
    if ! openssl x509 -inform DER -in "$cert_source" -out "$tmp_pem" 2>/dev/null; then
      rm -f "$tmp_pem"
      fail "Failed to convert .cer to PEM: $cert_source"
    fi
    cert_source="$tmp_pem"
  fi

  local -a pkcs12_args=(-export -inkey "$priv_key" -in "$cert_source" -out "$output" -passout pass:"$password")

  # Use -legacy on OpenSSL 3+ for macOS compatibility (RC2-40-CBC cipher).
  if openssl pkcs12 -help 2>&1 | grep -q -- "-legacy"; then
    pkcs12_args=("-legacy" "${pkcs12_args[@]}")
  fi

  if ! openssl pkcs12 "${pkcs12_args[@]}" 2>/dev/null; then
    [[ -n "$tmp_pem" ]] && rm -f "$tmp_pem"
    fail "Failed to build .p12 from key and certificate. Check that the key matches the certificate."
  fi

  [[ -n "$tmp_pem" ]] && rm -f "$tmp_pem"
  echo "Built p12 (legacy PKCS#12): $output"
}

input_dir="$SCRIPT_DIR/input"
output_dir="$SCRIPT_DIR/output"
env_file=""
key_file=""
p12_file=""
profile_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input-dir)
      input_dir="${2:-}"
      shift 2
      ;;
    --output-dir)
      output_dir="${2:-}"
      shift 2
      ;;
    --env-file)
      env_file="${2:-}"
      shift 2
      ;;
    --key-file)
      key_file="${2:-}"
      shift 2
      ;;
    --p12-file)
      p12_file="${2:-}"
      shift 2
      ;;
    --profile-file)
      profile_file="${2:-}"
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

[[ -d "$input_dir" ]] || fail "Input dir not found: $input_dir"
mkdir -p "$output_dir"

if [[ -z "$env_file" ]]; then
  env_file="$input_dir/vars.env"
fi
[[ -f "$env_file" ]] || fail "Missing env file: $env_file"

load_env_file "$env_file"

[[ -n "${APPLE_API_ISSUER_ID:-}" ]] || fail "APPLE_API_ISSUER_ID missing in $env_file"
[[ -n "${IOS_TEAM_ID:-}" ]] || fail "IOS_TEAM_ID missing in $env_file"
[[ -n "${IOS_DISTRIBUTION_CERTIFICATE_PASSWORD:-}" ]] || fail "IOS_DISTRIBUTION_CERTIFICATE_PASSWORD missing in $env_file"

if [[ -z "$key_file" ]]; then
  key_file="$(find_single_file "$input_dir" "AuthKey_*.p8" "key")"
fi

if [[ -z "$p12_file" ]]; then
  # Prefer building p12 from raw key + certificate when available.
  # This guarantees the -legacy PKCS#12 format required by macOS security import.
  priv_key="$(find_optional_file "$input_dir" "*.key")"
  cert_pem="$(find_optional_file "$input_dir" "*.pem")"
  cert_cer="$(find_optional_file "$input_dir" "*.cer")"
  cert_source="${cert_pem:-$cert_cer}"

  if [[ -n "$priv_key" && -n "$cert_source" ]]; then
    auto_p12="$input_dir/ios_distribution.p12"
    echo "Auto-building p12 from:"
    echo "  key: $priv_key"
    echo "  cert: $cert_source"
    build_p12 "$priv_key" "$cert_source" "$IOS_DISTRIBUTION_CERTIFICATE_PASSWORD" "$auto_p12"
    p12_file="$auto_p12"
  else
    # Fall back to existing p12 if no key/cert pair found.
    p12_file="$(find_single_file "$input_dir" "*.p12" "p12")"
  fi
fi

if [[ -z "$profile_file" ]]; then
  profile_file="$(find_single_file "$input_dir" "*.mobileprovision" "profile")"
fi

[[ -f "$key_file" ]] || fail "Key file not found: $key_file"
[[ -f "$p12_file" ]] || fail "p12 file not found: $p12_file"
[[ -f "$profile_file" ]] || fail "Provisioning profile not found: $profile_file"

testflight_output="$output_dir/testflight-secrets.env"
signing_output="$output_dir/ios-signing-secrets.env"
combined_output="$output_dir/github-secrets.env"
apply_script="$output_dir/apply-secrets-with-gh.sh"

testflight_args=(
  --issuer-id "$APPLE_API_ISSUER_ID"
  --key-file "$key_file"
  --output "$testflight_output"
)
if [[ -n "${APPLE_API_KEY_ID:-}" ]]; then
  testflight_args+=(--key-id "$APPLE_API_KEY_ID")
fi

"$SCRIPT_DIR/generate-testflight-secrets.sh" "${testflight_args[@]}"

signing_args=(
  --team-id "$IOS_TEAM_ID"
  --p12-file "$p12_file"
  --p12-password "$IOS_DISTRIBUTION_CERTIFICATE_PASSWORD"
  --profile-file "$profile_file"
  --output "$signing_output"
)
if [[ -n "${IOS_KEYCHAIN_PASSWORD:-}" ]]; then
  signing_args+=(--keychain-password "$IOS_KEYCHAIN_PASSWORD")
fi

"$SCRIPT_DIR/generate-ios-signing-secrets.sh" "${signing_args[@]}"

{
  cat "$testflight_output"
  echo
  cat "$signing_output"
} > "$combined_output"

cat > "$apply_script" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="${1:-$SCRIPT_DIR/github-secrets.env}"
REPO="${2:-}"

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) is not installed." >&2
  exit 1
fi

[[ -f "$SECRETS_FILE" ]] || {
  echo "Error: secrets file not found: $SECRETS_FILE" >&2
  exit 1
}

if [[ -z "$REPO" ]]; then
  if git -C "$SCRIPT_DIR/../.." rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    origin_url="$(git -C "$SCRIPT_DIR/../.." config --get remote.origin.url || true)"
    if [[ "$origin_url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
      REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
  fi
fi

if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi

if [[ -z "$REPO" ]]; then
  echo "Error: Unable to determine GitHub repo. Pass it explicitly as 2nd arg (owner/repo)." >&2
  exit 1
fi

echo "Target repo: $REPO"

while IFS= read -r line; do
  line="${line%$'\r'}"
  [[ -n "$line" ]] || continue
  [[ "$line" == \#* ]] && continue

  key="${line%%=*}"
  value="${line#*=}"

  if [[ -z "$key" ]]; then
    continue
  fi

  if [[ -z "$value" ]]; then
    echo "Error: Empty value for key $key in $SECRETS_FILE" >&2
    exit 1
  fi

  printf '%s' "$value" | gh secret set "$key" --repo "$REPO"
  echo "Set $key"
done < "$SECRETS_FILE"
EOF

chmod +x "$apply_script"

echo "Generated:"
echo "- $testflight_output"
echo "- $signing_output"
echo "- $combined_output"
echo "- $apply_script"
