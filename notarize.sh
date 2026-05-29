#!/usr/bin/env bash
#
# notarize.sh — one-shot release pipeline for DXClusterAggregator.
#
# Builds a universal (arm64 + x86_64) release binary, assembles the .app
# bundle, signs it with Manoj's Developer ID + hardened runtime, submits it
# to Apple's notary service, staples the ticket, and produces a distributable
# notarised zip ready to attach to a GitHub Release.
#
# The .app bundle and the *.zip are git-ignored (built fresh per release), so
# this script assembles the bundle from scratch when it is missing.
#
# One-time prerequisite — store the notarytool credentials once:
#   xcrun notarytool store-credentials DXC-NOTARY \
#     --apple-id <apple-id> --team-id CHVNJ85C9F --password <app-specific-pw>
#
# Usage:
#   ./notarize.sh [VERSION]
#     VERSION  e.g. 1.7.5. Optional if the .app already exists (read from its
#              Info.plist); required when building a fresh bundle.
#
# Overridable via env: DEV_ID, NOTARY_PROFILE, SDK, APP
set -euo pipefail
cd "$(dirname "$0")"

APP="${APP:-DXClusterAggregator.app}"
DEV_ID="${DEV_ID:-Developer ID Application: Manoj Ramawarrier (CHVNJ85C9F)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-DXC-NOTARY}"
ENT="DXClusterAggregator.entitlements"
BUNDLE_ID="com.vu2cpl.dxclusteraggregator"

# --- macOS 15 SDK pin -------------------------------------------------------
# Building with the default SDK 26 on Tahoe yields a binary that refuses to
# launch on macOS 15 / earlier. Prefer 15.4, fall back to 15.
SDK="${SDK:-}"
if [ -z "$SDK" ]; then
  for c in MacOSX15.4.sdk MacOSX15.sdk; do
    p="/Library/Developer/CommandLineTools/SDKs/$c"
    [ -d "$p" ] && SDK="$p" && break
  done
fi
[ -n "$SDK" ] || { echo "ERROR: no macOS 15 SDK found. Install one or pass SDK=/path/to/MacOSX15.sdk"; exit 1; }

# --- Resolve version --------------------------------------------------------
VER="${1:-}"
if [ -z "$VER" ] && [ -f "$APP/Contents/Info.plist" ]; then
  VER="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
fi
[ -n "$VER" ] || { echo "ERROR: no version. Pass it: ./notarize.sh 1.7.5"; exit 1; }

echo "==> Universal release build (SDK: $SDK)"
SDKROOT="$SDK" swift build -c release --arch arm64 --arch x86_64
REL=.build/apple/Products/Release

echo "==> Assembling $APP (v$VER)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$REL/DXClusterAggregator" "$APP/Contents/MacOS/DXClusterAggregator"
cp AppIcon.icns "$APP/Contents/Resources/" 2>/dev/null || true
rm -rf "$APP/Contents/Resources/DXClusterAggregator_DXClusterAggregator.bundle"
cp -R "$REL/DXClusterAggregator_DXClusterAggregator.bundle" "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

cat > "$APP/Contents/Resources/DXClusterAggregator_DXClusterAggregator.bundle/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}.resources</string>
    <key>CFBundlePackageType</key><string>BNDL</string>
    <key>CFBundleVersion</key><string>1</string>
</dict>
</plist>
PLIST

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>DXClusterAggregator</string>
    <key>CFBundleDisplayName</key><string>DX Cluster Aggregator</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key><string>${VER}</string>
    <key>CFBundleShortVersionString</key><string>${VER}</string>
    <key>CFBundleExecutable</key><string>DXClusterAggregator</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSLocalNetworkUsageDescription</key>
    <string>DX Cluster Aggregator needs network access to receive WSJT-X spots, connect to DX cluster nodes, and broadcast cluster data.</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key><true/>
        <key>NSAllowsArbitraryLoads</key><true/>
    </dict>
</dict>
</plist>
PLIST

# --- Developer ID sign (hardened runtime). Do NOT use --deep: sign the
#     nested resource bundle / binary explicitly, then the outer bundle. -----
echo "==> Developer ID signing (hardened runtime)"
xattr -cr "$APP"
codesign --force --options runtime --timestamp --entitlements "$ENT" \
  --sign "$DEV_ID" "$APP/Contents/MacOS/DXClusterAggregator"
codesign --force --options runtime --timestamp --entitlements "$ENT" \
  --sign "$DEV_ID" "$APP"
codesign -dvv "$APP" 2>&1 | grep -E "(runtime|Authority|Timestamp)" || true

NOTARY_ZIP="DXClusterAggregator-notary.zip"
DIST_ZIP="DXClusterAggregator-${VER}-notarized-universal.zip"
rm -f "$NOTARY_ZIP" "$DIST_ZIP"

echo "==> Submitting to Apple notary service (profile: $NOTARY_PROFILE) — waits for result"
ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling + verifying"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl -a -vvv -t exec "$APP" || true

echo "==> Building distribution zip (with stapled ticket): $DIST_ZIP"
rm -f "$NOTARY_ZIP"
ditto -c -k --keepParent "$APP" "$DIST_ZIP"

echo
echo "Done. Notarised + stapled: $DIST_ZIP"
echo "Next: gh release create v${VER} \"$DIST_ZIP\" --title \"v${VER}\" --notes-file <notes.md>"
