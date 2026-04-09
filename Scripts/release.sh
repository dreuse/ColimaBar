#!/bin/bash
set -euo pipefail

# Publishes a new ColimaBar release to GitHub and updates the Homebrew cask.
# Usage: ./Scripts/release.sh [version]
# Example: ./Scripts/release.sh 0.2.0
#
# Prerequisites:
#   - gh CLI authenticated (gh auth login)
#   - Xcode command line tools
#   - xcodegen installed

VERSION="${1:?Usage: release.sh <version>}"
REPO="dreuse/ColimaBar"
BUILD_DIR="build"

echo "==> Updating version to ${VERSION}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" ColimaBar/Resources/Info.plist

echo "==> Building release archive"
make clean zip

ZIP_PATH="${BUILD_DIR}/ColimaBar.zip"
SHA256=$(shasum -a 256 "${ZIP_PATH}" | cut -d' ' -f1)
echo "==> SHA-256: ${SHA256}"

echo "==> Creating GitHub release v${VERSION}"
gh release create "v${VERSION}" \
    "${ZIP_PATH}" \
    --repo "${REPO}" \
    --title "ColimaBar v${VERSION}" \
    --notes "ColimaBar v${VERSION}

## Install

\`\`\`bash
brew install --cask dreuse/tap/colimabar
\`\`\`

Or download \`ColimaBar.zip\`, extract, and drag to \`/Applications\`.

SHA-256: \`${SHA256}\`"

echo "==> Updating cask formula"
sed -i '' "s/version \".*\"/version \"${VERSION}\"/" Formula/colimabar.rb
sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" Formula/colimabar.rb

echo ""
echo "Done! Next steps:"
echo "  1. Commit the version bump + formula update"
echo "  2. If using a personal tap (dreuse/homebrew-tap), copy Formula/colimabar.rb there and push"
echo "  3. Users install with: brew install --cask dreuse/tap/colimabar"
