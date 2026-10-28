#!/usr/bin/env bash
# Sign a built DMG with the Sparkle EdDSA private key and print a complete
# appcast.xml listing that one version. The feed is published as a release
# asset next to the DMG, so `releases/latest/download/appcast.xml` (the
# SUFeedURL baked in by build-dmg.sh) always describes the latest release.
#
# The private key comes from SPARKLE_PRIVATE_KEY when set (CI), otherwise
# from the macOS Keychain (a release machine that ran generate_keys).
#
# Usage: bash scripts/sign-appcast.sh <DMG path> <version> > appcast.xml
# Example: bash scripts/sign-appcast.sh Dropshit.dmg 1.5.12 > appcast.xml

set -euo pipefail
cd "$(dirname "$0")/.."

DMG="${1:-Dropshit.dmg}"
VERSION="${2:-}"
# GitHub repo the release lives in; CI provides GITHUB_REPOSITORY.
REPO="${GITHUB_REPOSITORY:-sagaban/Dropshit}"

if [ -z "${VERSION}" ]; then
  echo "Usage: $0 <DMG path> <version>" >&2
  exit 1
fi

if [ ! -f "${DMG}" ]; then
  echo "ERROR: DMG not found at ${DMG}" >&2
  exit 1
fi

SIGN_TOOL="$(find .build -type f -name sign_update | head -1)"
if [ -z "${SIGN_TOOL}" ]; then
  echo "ERROR: sign_update not found — run 'swift package resolve' first." >&2
  exit 1
fi

# sign_update prints `sparkle:edSignature="..." length="..."` to stdout.
if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
  SIG_LINE="$(printf '%s' "${SPARKLE_PRIVATE_KEY}" | "${SIGN_TOOL}" --ed-key-file - "${DMG}")"
else
  SIG_LINE="$("${SIGN_TOOL}" "${DMG}")"
fi
PUBDATE="$(date -u +"%a, %d %b %Y %H:%M:%S +0000")"
DMG_NAME="$(basename "${DMG}")"
RELEASE_URL="https://github.com/${REPO}/releases/tag/v${VERSION}"

cat <<XML
<?xml version="1.0" standalone="yes"?>
<rss xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>Dropshit</title>
        <link>https://github.com/${REPO}/releases/latest/download/appcast.xml</link>
        <description>Latest Dropshit releases.</description>
        <language>en</language>
        <item>
            <title>Dropshit ${VERSION}</title>
            <link>${RELEASE_URL}</link>
            <sparkle:version>${VERSION}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
            <pubDate>${PUBDATE}</pubDate>
            <description><![CDATA[See release notes at ${RELEASE_URL}]]></description>
            <enclosure
                url="https://github.com/${REPO}/releases/download/v${VERSION}/${DMG_NAME}"
                ${SIG_LINE}
                type="application/octet-stream" />
        </item>
    </channel>
</rss>
XML
