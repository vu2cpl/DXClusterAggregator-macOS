# HANDOVER — DXClusterAggregator for macOS

Cold-start doc for picking this project back up. If you read only one file
to get oriented, read this one. Pairs with `README.md` (end-user facing) and
the in-app About line.

**Current version:** v1.7.5
**Last updated:** 2026-05-30
**Repo:** https://github.com/vu2cpl/DXClusterAggregator-macOS (branch: `main`)

---

## What it is

A native macOS (SwiftUI, menu-bar) app that aggregates FT8/FT4 spots from
multiple WSJT-X / JTDX instances (incoming UDP) **and** DX Cluster telnet
nodes into a single unified feed, then re-publishes that feed two ways:

- a **built-in telnet DX-cluster server** (default port `7575`) that logging
  software (Logger32, N1MM+, Log4OM, DXKeeper, …) connects to, and
- up to two **UDP broadcast destinations** (e.g. back out to RBN, or to
  another tool expecting WSJT-X UDP wire format).

On top of aggregation it does ClubLog-based alerting (New DXCC / Slot / Band /
Mode), LoTW-user marking, beacon detection, and macOS + Telegram notifications.

---

## Current state / defaults

| Setting | Default |
|---|---|
| Callsign | `VU2CPL` |
| WSJT-X/JTDX UDP listen port | `2237` |
| TCP cluster server port | `7575` (NOT 7550 — avoids SkimSrv's 7300/7550 defaults) |
| UDP Broadcast 1 | `127.0.0.1:2236` |
| Auto-clear window | `60` min (0 = disabled) |
| DX cluster auto-reconnect backoff | `10s → 30s → 60s → 120s → 300s` (last repeats) |

Settings persist via `@AppStorage` (`Models/Settings.swift`), Codable and
backward-compatible.

---

## Architecture map

Source of truth is `DXClusterAggregator/` (SwiftPM executable target,
`Package.swift`, `.process("Resources")` bundles the menu-bar icons).

- **`DXClusterAggregatorApp.swift`** — `@main` entry, menu-bar item, window
  lifecycle.
- **`ContentView.swift`** — the main view *and* the runtime orchestrator. Holds
  the `spots` array, display filters, start/stop of all clients, spot
  classification, rebroadcast + notification dedupe caches, and the
  auto-clear timer. (Big file — most behaviour lives here.)
- **`Network/`**
  - `DXClusterClient.swift` — telnet client to a cluster node. Auto-auth
    (login/password prompt detection, incl. hanging Telnet prompts + IAC
    stripping) and **auto-reconnect** with capped exponential backoff. One
    instance per configured node.
  - `ClusterTCPServer.swift` — the local telnet server logging software
    connects to. Tracks client connections under a lock; removes them on
    close.
  - `WSJTXUDPListener.swift` — receives WSJT-X/JTDX UDP datagrams.
  - `UDPBroadcaster.swift` — POSIX-socket UDP sender (raw sockets so
    `SO_BROADCAST` works); per-destination source allowlist + live counters.
  - `ClubLogClient.swift`, `LoTWDatabase.swift` — log download + LoTW user
    lookup. `SystemNotifier.swift`, `TelegramNotifier.swift` — alerts.
- **`Models/`** — `Settings`, `SpotMessage`, `ClubLogConfig`,
  `NotificationConfig`, `LogMatrix`.
- **`Protocol/`** — `ADIFParser`, `CTYParser`, `WSJTXMessageBuilder`,
  `WSJTXMessageParser` (WSJT-X UDP wire format encode/decode).
- **`Utils/`** — `AlertClassifier`, `BandResolver`, `BeaconDatabase`,
  `ClusterFormatter`, `DXCCResolver`, `ModeNormalizer`, `SpotLogger`.

---

## Build & release process

This machine is **macOS 26 (Tahoe)**; the default Swift SDK targets
macOS 26. **You must pin to the macOS 15 SDK** or the binary will refuse to
launch on macOS 15 (Sequoia) and earlier — this has bitten before.

### 1. Universal release build (SDK-15 pinned)

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk \
  swift build -c release --arch arm64 --arch x86_64
# universal binary lands in .build/apple/Products/Release/ (NOT .build/release/)
```

### 2. Assemble the `.app` bundle

Follow README → "Option 2 → Step 2". Copy
`.build/apple/Products/Release/DXClusterAggregator` into
`DXClusterAggregator.app/Contents/MacOS/`, copy `AppIcon.icns` and the
`DXClusterAggregator_DXClusterAggregator.bundle` resource bundle, and write
`Info.plist` with **`CFBundleShortVersionString` = the new version**.

### 3a. Quick local run — ad-hoc sign

```bash
codesign --force --deep --sign - DXClusterAggregator.app
```

Ad-hoc-signed apps are **not** notarised — opening one needs
`xattr -cr <app>` + right-click → Open. Fine for local testing.

### 3b. Release — Developer ID sign + notarise + staple

Releases ARE notarised (hardened runtime + `DXClusterAggregator.entitlements`).
This step needs Manoj's Apple Developer ID and a stored `notarytool`
keychain profile — **it cannot be done by an automated agent.**

```bash
codesign --force --options runtime --timestamp \
  --entitlements DXClusterAggregator.entitlements \
  --sign "Developer ID Application: <your name> (<TEAMID>)" \
  DXClusterAggregator.app

ditto -c -k --keepParent DXClusterAggregator.app \
  DXClusterAggregator-<version>-notarized-universal.zip

xcrun notarytool submit DXClusterAggregator-<version>-notarized-universal.zip \
  --keychain-profile "<notary-profile>" --wait

xcrun stapler staple DXClusterAggregator.app
# re-zip the stapled .app for distribution
```

### 4. Distribute

Attach the notarised `.zip` to a **GitHub Release**. Built artifacts are NOT
committed to the repo (see conventions below).

---

## Repo conventions

- **Built artifacts are not tracked.** The `.app` bundle and
  `DXClusterAggregator-*.zip` release archives are git-ignored
  (`.gitignore`). The repo holds source + docs only; the source tree is
  always the up-to-date truth. (Changed at v1.7.5 — before that the `.app`
  was committed per release, which caused the repo binary to drift from the
  notarised distributable.)
- **Version string lives in three places** — keep them in lockstep on every
  bump:
  1. `DXClusterAggregator/ContentView.swift` — the `Text("vX.Y.Z (macOS)")`
     footer.
  2. `generate_manual.py` — the cover `Version X.Y.Z` and the `CFBundleVersion`
     row in the Info.plist table.
  3. `README.md` — the `CFBundleVersion` / `CFBundleShortVersionString` in the
     build-from-source Info.plist example.
  4. (At build time) the bundle's `Contents/Info.plist`.
- **Regenerate the PDF manual** whenever `generate_manual.py` changes:
  `python3 generate_manual.py` (needs `reportlab` + `Pillow`). The committed
  `DXClusterAggregator_UserManual.pdf` must match the script.
- **Menu-bar icon source** is `DXClusterAggregator/Resources/MenuBarIcon*.png`
  (regenerate via `generate_menubar_icon.py`); `AppIcon.icns` via
  `generate_icon.py`.

---

## Known gotchas

- **SDK-26 launch failure (Tahoe).** Building with the system-default SDK 26
  produces a binary that won't launch on macOS 15/earlier. Always pin
  `SDKROOT=.../MacOSX15.sdk` for release builds. (Both `MacOSX15.sdk` and
  `MacOSX15.4.sdk` are installed under `/Library/Developer/CommandLineTools/SDKs/`.)
- **Telnet IAC noise.** Some AR-Cluster forks (e.g. N2WQ-2) prefix their banner
  with Telnet IAC option-negotiation bytes and use hanging (newline-less)
  prompts. `DXClusterClient.stripTelnetIAC` + the hanging-prompt path handle
  this; see comments there before touching auth detection.

---

## Recent history

- **v1.7.5** — Memory hardening: independent size caps on `notificationCooldown`
  and the `DXClusterClient` line buffer so neither grows unbounded during long
  uptime with auto-clear disabled. Stopped tracking built artifacts; docs
  (README, PDF manual, entitlements comment) brought in sync; this HANDOVER
  added.
- **v1.7.4** — Telnet IAC stripping + hanging-prompt support (N2WQ fix).
- **v1.7.3** — Tighter cluster login/password prompt detection.
- **v1.7.2** — Fix red-X close → main window couldn't be reopened.
- **v1.7.1** — Cluster format + WSJT-X UDP downstream-compat fixes.

---

## Open items

- _(none tracked at v1.7.5)_ — add here as they surface.
