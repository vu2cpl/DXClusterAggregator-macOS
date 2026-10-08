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
#     VERSION  e.g. 1.8.6. Optional: defaults to the version in the
#              ContentView footer (`Text("vX.Y.Z (macOS)")`), and when given it
#              must match that footer — bump the footer first.
#
# Every run builds from scratch: the old .app and the old build product are
# deleted first, the product path is asked of SwiftPM rather than assumed, and
# the script stops if the fresh binary is missing, not universal, has the
# wrong deployment target, or is not byte-identical to what went into the .app.
#
# Overridable via env: DEV_ID, NOTARY_PROFILE, APP, DEVELOPER_DIR (selects the
#   Xcode, and with it the macOS SDK, that the build uses),
#   CLUBLOG_API_KEY   (40-hex key to embed; default: read from the
#                      installed app's own preferences)
#   EMBED_CLUBLOG_KEY (0 = build without the built-in ClubLog key)
set -euo pipefail
cd "$(dirname "$0")"

APP="${APP:-DXClusterAggregator.app}"
DEV_ID="${DEV_ID:-Developer ID Application: Manoj Ramawarrier (CHVNJ85C9F)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-DXC-NOTARY}"
ENT="DXClusterAggregator.entitlements"
BUNDLE_ID="com.vu2cpl.dxclusteraggregator"

# --- SDK + deployment target ----------------------------------------------
# Releases up to v1.8.5 pinned SDKROOT to a macOS 15 SDK so the binary would
# launch on macOS 15 and earlier. Dropped 2026-10-09: no macOS 15 SDK is
# installed any more, and the pin was never in force anyway — Swift 6.4's
# default build system (swiftbuild) ignores SDKROOT and --sdk, and every
# release from v1.7.5 to v1.8.5 records sdk 26.5 in its LC_BUILD_VERSION. What
# decides whether the binary loads on an older macOS is its deployment target
# (minos, from Package.swift) and not depending on any @rpath back-deployment
# dylib this hand-assembled bundle would not carry; both are checked below.
# The build uses the active developer directory's macOS SDK.
SDK="$(xcrun --sdk macosx --show-sdk-path)"
SDK_VER="$(xcrun --sdk macosx --show-sdk-version)"
MIN_OS="14.0"   # Package.swift .macOS(.v14); also LSMinimumSystemVersion below
[ -d "$SDK" ] && [ -n "$SDK_VER" ] || { echo "ERROR: no macOS SDK found (xcrun --sdk macosx)"; exit 1; }

# --- Resolve version --------------------------------------------------------
FOOTER_SRC=DXClusterAggregator/ContentView.swift
FOOTER_VER="$(sed -nE 's/.*Text\("v([0-9][0-9.]*) \(macOS\)"\).*/\1/p' "$FOOTER_SRC" | head -1)"
VER="${1:-$FOOTER_VER}"
[ -n "$VER" ] || { echo "ERROR: no version. Pass it: ./notarize.sh 1.8.6"; exit 1; }
[ "$VER" = "$FOOTER_VER" ] || {
  echo "ERROR: version $VER does not match the $FOOTER_SRC footer (v$FOOTER_VER)."
  echo "       Bump the footer (and generate_manual.py, README) first."
  exit 1
}

# --- ClubLog API key injection ---------------------------------------------
# The key ships in the binary (Club Log issues it per application, and cty.xml
# is the same file for every user) but must never reach the repo: Club Log
# delete keys they find published in a Git repository, and this repo is public.
# So it is injected for the build and cleared again on the way out - including
# on failure or Ctrl-C, which is what the trap is for. Set EMBED_CLUBLOG_KEY=0
# to build a release without it (users then supply their own key in Settings).
KEYGEN=./scripts/embed_clublog_key.py
if [ "${EMBED_CLUBLOG_KEY:-1}" = "1" ]; then
  trap '"$KEYGEN" --clear >/dev/null' EXIT
  echo "==> Injecting the ClubLog API key (cleared again when this script exits)"
  "$KEYGEN" ${CLUBLOG_API_KEY:+"$CLUBLOG_API_KEY"} || {
    echo "ERROR: no ClubLog API key to embed. Set it in the app's Settings, or"
    echo "       pass CLUBLOG_API_KEY=<40-hex>, or EMBED_CLUBLOG_KEY=0 to skip."
    exit 1
  }
else
  echo "==> EMBED_CLUBLOG_KEY=0 — building WITHOUT the built-in ClubLog key"
  "$KEYGEN" --clear >/dev/null
fi

# --- Universal release build ---------------------------------------------
# Ask SwiftPM where the product goes instead of hard-coding it: the native build
# system wrote universal builds to .build/apple/Products/Release, Swift 6.4's
# swiftbuild writes .build/out/Products/Release, and a stale binary left in the
# old place was one wrong path away from shipping. The product is deleted
# before the build, so whatever is there afterwards was linked by this run.
BUILD_ARGS=(-c release --arch arm64 --arch x86_64)
REL="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
BIN="$REL/DXClusterAggregator"
RES="$REL/DXClusterAggregator_DXClusterAggregator.bundle"
rm -rf "$BIN" "$RES"

echo "==> Universal release build (macOS SDK $SDK_VER, minimum macOS $MIN_OS) -> $REL"
# -isysroot for the link step: swiftbuild links through `swiftc -sdk`, which
# hands clang only --sysroot, so ld records the deployment target as the SDK
# version (sdk 14.0). The recorded SDK version is what macOS keys its
# linked-on-or-after behaviour on, so pass the real SDK and check it below.
swift build "${BUILD_ARGS[@]}" \
  -Xswiftc -Xclang-linker -Xswiftc -isysroot -Xswiftc -Xclang-linker -Xswiftc "$SDK"

fail() { echo "ERROR: $*"; exit 1; }
[ -f "$BIN" ] || fail "the build did not produce $BIN"
[ -d "$RES" ] || fail "the build did not produce $RES"
ARCHS=" $(lipo -archs "$BIN") "
for a in arm64 x86_64; do
  case "$ARCHS" in *" $a "*) ;; *) fail "$BIN lacks $a (has:$ARCHS)";; esac
  BV="$(vtool -arch "$a" -show-build "$BIN")"
  minos="$(awk '$1=="minos"{print $2}' <<<"$BV")"
  sdk="$(awk '$1=="sdk"{print $2}' <<<"$BV")"
  [ "$minos" = "$MIN_OS" ] || fail "$a slice has minos $minos, expected $MIN_OS"
  [ "$sdk" = "$SDK_VER" ] || fail "$a slice records sdk $sdk, expected $SDK_VER"
done
if otool -L "$BIN" | grep -q '@rpath/'; then
  otool -L "$BIN" | grep '@rpath/'
  fail "the binary needs @rpath dylibs this bundle does not carry"
fi
echo "    built $(stat -f '%Sm' "$BIN"); archs:${ARCHS}minos $MIN_OS, sdk $SDK_VER"

echo "==> Assembling $APP (v$VER) from scratch"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DXClusterAggregator"
cmp -s "$BIN" "$APP/Contents/MacOS/DXClusterAggregator" \
  || fail "the binary in $APP is not the one just built"
cp AppIcon.icns "$APP/Contents/Resources/" 2>/dev/null || true
cp -R "$RES" "$APP/Contents/Resources/"
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
    <key>LSMinimumSystemVersion</key><string>${MIN_OS}</string>
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
ditto -c -k --norsrc --keepParent "$APP" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling + verifying"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict "$APP"
spctl -a -vvv -t exec "$APP"

echo "==> Building distribution zip (with stapled ticket): $DIST_ZIP"
rm -f "$NOTARY_ZIP"
# --norsrc: no AppleDouble (._*) sidecars for extended attributes — an
# unzipper that turns them into real files breaks the signature.
ditto -c -k --norsrc --keepParent "$APP" "$DIST_ZIP"
SIDECARS="$(zipinfo -1 "$DIST_ZIP" | grep -c -E '(^|/)(\._|__MACOSX)' || true)"
[ "$SIDECARS" = "0" ] || fail "$DIST_ZIP contains $SIDECARS AppleDouble entries"

echo
echo "Done. Notarised + stapled: $DIST_ZIP"
shasum -a 256 "$DIST_ZIP"
echo "Next: gh release create v${VER} \"$DIST_ZIP\" --title \"v${VER}\" --notes-file <notes.md>"
