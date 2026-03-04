#!/bin/bash

# Usage: ./scripts/bump-version.sh <version|version+build> [--force]
# Example: ./scripts/bump-version.sh 1.1.9
# Example: ./scripts/bump-version.sh 1.1.9+42
# Example: ./scripts/bump-version.sh 0.1.0 --force

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PUBSPEC="${PROJECT_ROOT}/pubspec.yaml"
ANDROID_LOCAL_PROPERTIES="${PROJECT_ROOT}/android/local.properties"
IOS_GENERATED_XCCONFIG="${PROJECT_ROOT}/ios/Flutter/Generated.xcconfig"
IOS_PBXPROJ="${PROJECT_ROOT}/ios/Runner.xcodeproj/project.pbxproj"
VERSION_DIR="${SCRIPT_DIR}/version"

INPUT_VERSION="${1:-}"
FORCE=false

if [ "$#" -gt 1 ]; then
  shift
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --force)
        FORCE=true
        ;;
      *)
        echo "Error: unknown option '$1'"
        echo "Usage: $0 <version|version+build> [--force]"
        exit 1
        ;;
    esac
    shift
  done
fi

if [ -z "${INPUT_VERSION}" ]; then
  echo "Usage: $0 <version|version+build> [--force]"
  echo "Example: $0 1.1.9"
  echo "Example: $0 1.1.9+42"
  echo "Example: $0 0.1.0 --force"
  exit 1
fi

# Validate version format (x.y.z or x.y.z+n)
if ! echo "${INPUT_VERSION}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$'; then
  echo "Error: version must be in format x.y.z or x.y.z+build (e.g. 1.1.9 or 1.1.9+42)"
  exit 1
fi

VERSION_NAME="${INPUT_VERSION%%+*}"

# Read current version from pubspec
CURRENT_VERSION_FULL="$(grep '^version:' "${PUBSPEC}" | sed -E 's/version:[[:space:]]*//')"
CURRENT_VERSION_NAME="${CURRENT_VERSION_FULL%%+*}"
CURRENT_BUILD="${CURRENT_VERSION_FULL##*+}"

# Compare semver: split into major.minor.patch and compare numerically
semver_gt() {
  # Returns 0 (true) if $1 > $2
  local IFS=.
  local a=($1) b=($2)
  for i in 0 1 2; do
    local av="${a[$i]:-0}" bv="${b[$i]:-0}"
    if (( av > bv )); then return 0; fi
    if (( av < bv )); then return 1; fi
  done
  return 1  # equal
}

# Determine latest known version from current pubspec and existing release tags.
LATEST_VERSION="${CURRENT_VERSION_NAME}"
LATEST_TAG_VERSION="$(git -C "${PROJECT_ROOT}" tag --list 'v[0-9]*.[0-9]*.[0-9]*' | sed 's/^v//' | sort -V | tail -n1)"
if [ -n "${LATEST_TAG_VERSION}" ] && semver_gt "${LATEST_TAG_VERSION}" "${LATEST_VERSION}"; then
  LATEST_VERSION="${LATEST_TAG_VERSION}"
fi

if ! semver_gt "${VERSION_NAME}" "${LATEST_VERSION}" && [ "${FORCE}" != "true" ]; then
  echo "Error: ${VERSION_NAME} must be greater than latest version (${LATEST_VERSION})."
  echo "Use a higher version number or pass --force to override."
  exit 1
fi

if [ "${FORCE}" = "true" ]; then
  echo "Warning: --force enabled. Skipping latest-version check (latest: ${LATEST_VERSION}, requested: ${VERSION_NAME})."
fi

if echo "${INPUT_VERSION}" | grep -q '+'; then
  BUILD_NUMBER="${INPUT_VERSION#*+}"
else
  BUILD_NUMBER="$((CURRENT_BUILD + 1))"
fi

VERSION_FULL="${VERSION_NAME}+${BUILD_NUMBER}"

echo "Updating app version to ${VERSION_FULL}..."

# 1) Update Flutter version source of truth
sed -i "s/^version: .*/version: ${VERSION_FULL}/" "${PUBSPEC}"

# 1) Update Android resolved values used by Gradle
if [ -f "${ANDROID_LOCAL_PROPERTIES}" ]; then
  sed -i "s/^flutter\.versionName=.*/flutter.versionName=${VERSION_NAME}/" "${ANDROID_LOCAL_PROPERTIES}"
  sed -i "s/^flutter\.versionCode=.*/flutter.versionCode=${BUILD_NUMBER}/" "${ANDROID_LOCAL_PROPERTIES}"
fi

# 1) Update iOS resolved values when generated file exists
if [ -f "${IOS_GENERATED_XCCONFIG}" ]; then
  sed -i "s/^FLUTTER_BUILD_NAME=.*/FLUTTER_BUILD_NAME=${VERSION_NAME}/" "${IOS_GENERATED_XCCONFIG}"
  sed -i "s/^FLUTTER_BUILD_NUMBER=.*/FLUTTER_BUILD_NUMBER=${BUILD_NUMBER}/" "${IOS_GENERATED_XCCONFIG}"
fi

# 1) Keep iOS test target marketing/build version aligned
if [ -f "${IOS_PBXPROJ}" ]; then
  sed -i "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = ${VERSION_NAME}/g" "${IOS_PBXPROJ}"
  sed -i "s/CURRENT_PROJECT_VERSION = [0-9][0-9]*/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER}/g" "${IOS_PBXPROJ}"
fi

echo "✓ Updated ${PUBSPEC}"
echo "✓ $(grep '^version:' "${PUBSPEC}")"

# 2) Create version markdown file
mkdir -p "${VERSION_DIR}"
VERSION_FILE="${VERSION_DIR}/${VERSION_NAME}.md"

LAST_TAG="$(git -C "${PROJECT_ROOT}" describe --tags --abbrev=0 2>/dev/null || true)"
if [ -n "${LAST_TAG}" ]; then
  CHANGELOG_ENTRIES="$(git -C "${PROJECT_ROOT}" log "${LAST_TAG}"..HEAD --pretty=format:'- %s' || true)"
else
  CHANGELOG_ENTRIES="$(git -C "${PROJECT_ROOT}" log --max-count=20 --pretty=format:'- %s' || true)"
fi

if [ -z "${CHANGELOG_ENTRIES}" ]; then
  CHANGELOG_ENTRIES="- Version bump and release metadata update"
fi

cat > "${VERSION_FILE}" <<EOF
# Version ${VERSION_NAME}

- Date: $(date +%F)
- Build: ${BUILD_NUMBER}

## What changed

${CHANGELOG_ENTRIES}

## Release updates included

- Updated pubspec version to ${VERSION_FULL}
- Synced Android versionName/versionCode
- Synced iOS build/version values where applicable
EOF

echo "✓ Created ${VERSION_FILE}"

# 2.1) Keep only latest version note file
find "${VERSION_DIR}" -maxdepth 1 -type f -name '*.md' ! -name "${VERSION_NAME}.md" -delete
echo "✓ Removed old version notes in ${VERSION_DIR} (kept ${VERSION_NAME}.md)"

# 3) Add and commit
git -C "${PROJECT_ROOT}" add \
  "${PUBSPEC}" \
  "${ANDROID_LOCAL_PROPERTIES}" \
  "${IOS_PBXPROJ}" \
  "${VERSION_FILE}" || true
git -C "${PROJECT_ROOT}" add -A "${VERSION_DIR}" || true

if [ -f "${IOS_GENERATED_XCCONFIG}" ]; then
  git -C "${PROJECT_ROOT}" add "${IOS_GENERATED_XCCONFIG}" || true
fi

COMMIT_MSG="chore(release): bump mobile to ${VERSION_FULL}"
TAG_NAME="v${VERSION_NAME}"

if git -C "${PROJECT_ROOT}" diff --cached --quiet; then
  echo "No staged changes to commit."
else
  git -C "${PROJECT_ROOT}" commit -m "${COMMIT_MSG}"
  echo "✓ Committed: ${COMMIT_MSG}"
fi

# 4) Create tag
if git -C "${PROJECT_ROOT}" rev-parse "${TAG_NAME}" >/dev/null 2>&1; then
  echo "Warning: tag ${TAG_NAME} already exists. Skipping tag creation."
else
  git -C "${PROJECT_ROOT}" tag "${TAG_NAME}"
  echo "✓ Created tag: ${TAG_NAME}"
fi

# 5) Push
CURRENT_BRANCH="$(git -C "${PROJECT_ROOT}" branch --show-current)"
if [ -z "${CURRENT_BRANCH}" ]; then
  echo "Warning: could not determine current branch. Skipping push."
else
  git -C "${PROJECT_ROOT}" push origin "${CURRENT_BRANCH}"
  git -C "${PROJECT_ROOT}" push origin "${TAG_NAME}"
  echo "✓ Pushed to origin/${CURRENT_BRANCH} and tag ${TAG_NAME}"
fi

echo
echo "Done! Version is now ${VERSION_FULL}"
