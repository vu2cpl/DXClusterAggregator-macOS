# HANDOVER — DXClusterAggregator for macOS

Cold-start doc for picking this project back up. If you read only one file
to get oriented, read this one. Pairs with `README.md` (end-user facing) and
the in-app About line.

**Current version:** v1.7.6
**Last updated:** 2026-06-28
**Repo:** https://github.com/vu2cpl/DXClusterAggregator-macOS (branch: `main`)

---

## Working directory

**Canonical:** `/Users/manoj/projects/DXClusterAggregator/` — the real checkout
(live `.git`, sources, build artifacts). The folder was historically named
`FT8ClusterAggregator`, since renamed to match the project; the GitHub repo was
likewise renamed from `FT8ClusterAggregator-macOS` (old URL still
301-redirects). If a stale stub reappears at
`~/Documents/Claude/code/FT8ClusterAggregator/`, ignore it — it was deleted.

> Claude sessions run in a git worktree under `.claude/worktrees/…` and push to
> `origin/main`. The canonical checkout above must `git pull` to catch up —
> delete any untracked file that would block the merge first.

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
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  swift build -c release --arch arm64 --arch x86_64
# universal binary lands in .build/apple/Products/Release/ (NOT .build/release/)
# (15.4 is canonical; MacOSX15.sdk also works — any macOS 15 SDK, NOT 26.)
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

### 3b. Release — `./notarize.sh`

The whole release pipeline is scripted. From a clean checkout:

```bash
./notarize.sh 1.7.5     # version arg; omit if the .app already carries it
```

`notarize.sh` builds the universal binary (SDK-15 pinned), assembles the
`.app` (writing `Info.plist` with the given version), Developer-ID signs it
with hardened runtime + `DXClusterAggregator.entitlements`, submits to Apple's
notary service, staples the ticket, verifies, and emits
`DXClusterAggregator-<version>-notarized-universal.zip`.

Prereq: the `notarytool` credentials must be stored once as keychain profile
**`DXC-NOTARY`** (`xcrun notarytool store-credentials DXC-NOTARY …`). Manoj's
Developer ID is `Developer ID Application: Manoj Ramawarrier (CHVNJ85C9F)`.
With the profile stored the run is non-interactive. (The script's defaults are
overridable via the `DEV_ID` / `NOTARY_PROFILE` / `SDK` env vars.)

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

## Integration & operating notes

- **RUMlog has two separate listening modes — don't confuse them:**
  - *WSJT-X port* (e.g. 2347) = QSO-logging integration; it listens for
    `QSO Logged` (type 5) messages only and ignores decode-derived spots, so
    sending Status+Decode pairs there is pointless.
  - *DX Cluster tab* = a TCP cluster client. Point it at our local cluster
    server (`127.0.0.1:7575`) to get spots in RUMlog's DX Spots window — this
    is the right path for cluster spots.
- **Single-session-per-callsign clusters** (e.g. N2WQ allow one login per
  call). If your call is already connected from another client, set the
  cluster row's **Username** to `CALLSIGN-N` (any AX.25 SSID `-1`…`-15`); the
  cluster treats it as a distinct user. No code change — `username` is
  free-form. (Manoj uses `VU2CPL-2` for N2WQ.)

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

- **v1.7.6** — Fix minimised-window restore: both `WindowManager.showMainWindow`
  and `applicationShouldHandleReopen` now call `deminiaturize(nil)` when the
  window is sitting in the Dock as a thumbnail. Previously `makeKeyAndOrderFront`
  alone only reordered z-stack, leaving the window minimised — the menu-bar
  "Show Window" entry appeared to do nothing.
- **v1.7.5** — Memory hardening: independent size caps on `notificationCooldown`
  and the `DXClusterClient` line buffer so neither grows unbounded during long
  uptime with auto-clear disabled. Fixed the default TCP cluster port
  (`7550 → 7575`, avoids SkimSrv's 7300/7550 clash) with a one-time launch
  migration (`didMigrateClusterPort7575` flag) that bumps an existing stored
  7550. Stopped tracking built artifacts; added `notarize.sh` (scripted
  release pipeline); docs (README, PDF manual, entitlements comment) brought
  in sync; this HANDOVER added.
- **v1.7.4** — Telnet IAC stripping + hanging-prompt support (N2WQ fix).
- **v1.7.3** — Tighter cluster login/password prompt detection.
- **v1.7.2** — Fix red-X close → main window couldn't be reopened.
- **v1.7.1** — Cluster format + WSJT-X UDP downstream-compat fixes.

---

## Open items

- `SpotMessage.dxCallsign`'s `looksLikeCallsign` heuristic is defensive but not
  exhaustive — pathological FT8 messages could still slip a non-call into the
  callsign column. Revisit if a user reports it.
- `stripTelnetIAC` drops trailing partial IAC sequences that span packet
  boundaries. Harmless in practice (clusters emit the IAC preamble in one
  initial segment); revisit if a cluster interleaves IAC commands mid-session.
