#!/bin/bash

# Usage: ./scripts/bump-version.sh <version>
# Example: ./scripts/bump-version.sh 1.1.9

set -e

VERSION=$1
PUBSPEC="./pubspec.yaml"

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 1.1.9"
  exit 1
fi

# Validate version format (x.y.z)
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Error: version must be in format x.y.z (e.g. 1.1.9)"
  exit 1
fi

echo "Updating version to $VERSION..."

# Update only the version name, keep existing build number
CURRENT_BUILD=$(grep "^version:" "$PUBSPEC" | sed 's/version: [^+]*+//')
sed -i "s/^version: .*/version: $VERSION+$CURRENT_BUILD/" "$PUBSPEC"

echo "✓ Updated $PUBSPEC"
echo "✓ $(grep "^version:" "$PUBSPEC")"

# Create git tag
TAG="v$VERSION"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Warning: tag $TAG already exists. Skipping tag creation."
else
  git add "$PUBSPEC"
  git commit -m "chore: bump version to $VERSION"
  git tag "$TAG"
  echo "✓ Created git tag: $TAG"
  echo ""
  echo "To push: git push && git push origin $TAG"
fi

echo ""
echo "Done! Version is now $VERSION"
