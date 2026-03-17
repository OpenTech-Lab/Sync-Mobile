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
