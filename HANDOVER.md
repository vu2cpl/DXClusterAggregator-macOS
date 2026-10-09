# HANDOVER — DXClusterAggregator for macOS

Cold-start doc for picking this project back up. If you read only one file
to get oriented, read this one. Pairs with `README.md` (end-user facing) and
the in-app About line.

**Current version:** v1.8.7 (released + notarized 2026-10-09 — the cluster
line in RBN Aggregator's shape with relayed comments verbatim, and the update
dialog that stays out of the way; v1.8.6, the same day, added the update
check). Installed at
`/Applications/DXClusterAggregator.app` (not running — it stays closed while a
dxca instance holds the same ports).
· **SHELVED / MAINTENANCE MODE** — superseded by DXCA 2.0 (`vu2cpl/dxca`),
in production on noderedpi4 since 2026-08-27. This app is the tested
fallback: no planned work, fixes only if the fallback is ever needed.
v1.8.4 was called the final *feature* release and that still holds —
v1.8.5 exists because a first-run wall (every user obtaining their own
ClubLog developer key by hand) and a ClubLog API-policy breach (retrying
a 403) were both worth fixing in the fallback. v1.8.6 adds the update
check shared by all five VU2CPL Swift apps. The release pipeline
(`./notarize.sh`) remains fully scripted, fixed for Swift 6.4 on 2026-10-09.

**Last updated:** 2026-10-09 (v1.8.7 released: the cluster line in Aggregator's shape; v1.8.6 released earlier the same day; `notarize.sh` fixed for Swift 6.4)
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
| Spot log size cap (`DXC Spots.txt`) | `100` MB (0 = unlimited; trims oldest lines to ~75% of cap) |
| DX cluster auto-reconnect backoff | `10s → 30s → 60s → 120s → 300s` (last repeats) |

Settings persist via `@AppStorage` (`Models/Settings.swift`), Codable and
backward-compatible.

---

## Architecture map

Source of truth is `DXClusterAggregator/` (SwiftPM executable target,
`Package.swift`, `.process("Resources")` bundles the menu-bar icons).

- **`DXClusterAggregatorApp.swift`** — `@main` entry, menu-bar item, window
  lifecycle.
- **`UpdateChecker.swift`** — the GitHub-releases update check. Identical in
  all five VU2CPL Swift apps; never edit it here alone — fix it, then copy the
  whole file to the other four repos.
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
  `ClusterFormatter`, `DXCCResolver`, `ModeNormalizer`, `SpotLogger`,
  `BuiltInCredentials` (generated — the shipped ClubLog API key, see
  *Repo conventions*).

---

## Build & release process

This machine is **macOS 27** with Xcode's Swift 6.4 and the macOS 27 SDK
(the Command Line Tools also hold 26.5; there is no macOS 15 SDK any more).
The deployment target — `.macOS(.v14)` in `Package.swift`, `minos 14.0` in
the binary — is what lets a release load on Sonoma and later; the old SDK-15
pin is gone (see the 2026-10-09 entry under *Recent history*).

### 1. Universal release build

```bash
swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
# Swift 6.4 (swiftbuild): .build/out/Products/Release/
# older toolchains (native): .build/apple/Products/Release/ — ask, don't assume
```

### 2. Assemble the `.app` bundle

Follow README → "Option 2 → Step 2". Copy
`$BIN/DXClusterAggregator` into
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

`notarize.sh` deletes the old build product and the old `.app`, builds the
universal binary, asks SwiftPM where it went (`--show-bin-path`), and stops
unless it exists, has both arm64 and x86_64, records `minos 14.0` and the
SDK actually used, and needs no `@rpath` dylib. It then assembles the `.app`
from scratch (`Info.plist` with the version, which defaults to and must match
the `ContentView` footer), checks the copied binary is byte-identical to the
build, Developer-ID signs it with hardened runtime +
`DXClusterAggregator.entitlements`, submits to Apple's notary service,
staples, verifies (`codesign --strict`, `spctl`, both fatal), and emits
`DXClusterAggregator-<version>-notarized-universal.zip` made with
`ditto --norsrc` (0 AppleDouble entries, checked) and prints its SHA-256.

Prereq: the `notarytool` credentials must be stored once as keychain profile
**`DXC-NOTARY`** (`xcrun notarytool store-credentials DXC-NOTARY …`). Manoj's
Developer ID is `Developer ID Application: Manoj Ramawarrier (CHVNJ85C9F)`.
With the profile stored the run is non-interactive. (The script's defaults are
overridable via the `DEV_ID` / `NOTARY_PROFILE` / `DEVELOPER_DIR` env vars.)

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
- **The ClubLog developer API key is injected at build time and never
  committed.** `DXClusterAggregator/Utils/BuiltInCredentials.swift` is
  generated by `scripts/embed_clublog_key.py` — **do not hand-edit**. Its
  *tracked* form holds an **empty** key, so a fresh clone builds and runs
  (the app just falls back to the Settings field, as it always did).
  `notarize.sh` injects the real key before the release build and clears it
  again from a `trap … EXIT`, so it survives Ctrl-C and build failures; a
  release therefore ships the key while the repo never sees it. Manual use:
  `./scripts/embed_clublog_key.py [<40-hex-key>]` to inject (no argument reads
  the installed app's own preferences), `--clear` to restore the empty form.
  **If you inject by hand, check `git diff` before committing.**
  - *Why this shape, and not simply committing the key:* Club Log's
    [API Keys](https://clublog.freshdesk.com/support/solutions/articles/54910-api-keys)
    article says a key is specific to your *application* — which is exactly
    why embedding one in the app is right, and why making each user request
    their own was pointless — but also that keys found published on the web or
    **in a Git repository** are deleted without notice, with the products
    using them liable to be blocked. This repo is public. The XOR pad is *not*
    the answer to that: it is there only so a shipped `.app` doesn't hand the
    key to `strings`, and dodging Club Log's scanners with it would be the
    wrong response to a policy that exists for good reason.
  - The file stays **tracked** (in empty form) rather than git-ignored on
    purpose — that is what keeps `swift build` working on a fresh clone.
    Don't "fix" it by adding it to `.gitignore`.
  - Rotation: new key from ClubLog → it goes in the app's Settings (or
    `CLUBLOG_API_KEY=…`) → next `./notarize.sh` picks it up. Nothing to edit.
  - Per-operator secrets (callsign, email, app password, Telegram token) are
    deliberately never injected: those authenticate a person, not the app.
  - **A ClubLog 403 latches, and the latch is a fingerprint.**
    `Utils/ClubLogRejection.swift` stores a SHA-256 of the credentials that
    were rejected — the API key, and separately the callsign/email/app
    password — and `ClubLogClient.refresh` refuses to send a set that matches
    before it reaches the network. ClubLog ask that a 403 stop further
    requests immediately, because their reactive firewall blocks the source IP
    for repeated bad-credential traffic; that would cut off ClubLog for the
    whole shack, invisibly, since a firewalled host just stops getting
    answers. A fingerprint rather than a flag means **there is no reset button
    to find**: change the key or the password and it no longer matches, so the
    next Refresh simply goes through. Any successful download clears it too,
    for credentials that start working again on ClubLog's side.
- **Menu-bar icon source** is `DXClusterAggregator/Resources/MenuBarIcon*.png`
  (regenerate via `generate_menubar_icon.py`); `AppIcon.icns` via
  `generate_icon.py`.

---

## Integration & operating notes

- **Multi-app UDP topology (MSHV + JTDX + WSJT-X + RUMlogNG + DXCA):** the
  canonical wiring is documented in
  [`docs/UDP-PIPELINE.md`](docs/UDP-PIPELINE.md) — with screenshots of every
  panel. The rule: DXCA is the sole listener on every WSJT-X port; each
  decoder targets a distinct DXCA input port (2333 MSHV / 2334 JTDX / 2335
  WSJT-X); DXCA rebroadcasts every spot in WSJT-X wire format to
  `127.0.0.1:2237` where RUMlog's WSJT-X Data Port picks it up. **Superseded
  2026-08-28:** this entry went on to describe MSHV's *Simplified UDP
  Broadcast* to `127.0.0.1:2233` as the only working MSHV → RUMlog
  logged-QSO path. It isn't — passthrough carries type-5 to 2237 like
  everything else, and the one setting actually required is MSHV's *Enable
  Logged QSO*. See the Known-gotcha entry below and
  [`docs/UDP-PIPELINE.md`](docs/UDP-PIPELINE.md). This setup survives any
  reboot order (every port has
  exactly one binder). Add this to the checklist when a user reports
  "aggregator is hung after a reboot" — usually it's another app racing to
  grab a WSJT-X port at login. Read the doc before touching any port number.
- **RUMlog has two separate listening modes — don't confuse them:**
  - *WSJT-X port* (Data Port, default 2237) = QSO-logging + dx-spot-table
    ingest; it consumes WSJT-X binary datagrams (Status/Decode for the
    dx-spot table, QSO Logged for the log). This is where DXCA rebroadcasts.
  - *DX Cluster tab* = a TCP cluster client. Point it at our local cluster
    server (`127.0.0.1:7575`) to get spots in RUMlog's DX Spots window.
  Both paths can feed the DX Spots table simultaneously; duplicates are
  expected. Disable "Populate dx-spot table" under WSJT-X (or disconnect the
  cluster tab from DXCA) to pick a single source.
- **Single-session-per-callsign clusters** (e.g. N2WQ allow one login per
  call). If your call is already connected from another client, set the
  cluster row's **Username** to `CALLSIGN-N` (any AX.25 SSID `-1`…`-15`); the
  cluster treats it as a distinct user. No code change — `username` is
  free-form. (Manoj uses `VU2CPL-2` for N2WQ.)

---

## Known gotchas

- **SDK and older macOS.** The April 2026 note said an SDK-26 build would not
  launch on macOS 15, and release builds pinned `SDKROOT` to a macOS 15 SDK.
  That pin never took effect through `notarize.sh`: v1.7.5 to v1.8.5 all
  record `sdk 26.5`, `minos 14.0` in `LC_BUILD_VERSION` (checked 2026-10-09
  with `vtool -show-build`). What matters for older systems is `minos` and
  not linking an `@rpath` back-deployment dylib (e.g.
  `libswiftCompatibilitySpan.dylib`), which a hand-assembled bundle would not
  carry; `notarize.sh` checks both. Not tested on a real macOS 14/15 machine.
- **Swift 6.4 records the wrong SDK unless told.** swiftbuild links through
  `swiftc -sdk`, which gives clang only `--sysroot`, so `ld` writes the
  deployment target as the SDK version (`sdk 14.0`) and macOS then applies
  pre-26 linked-on-or-after behaviour. `SDKROOT` and `--sdk` are both ignored;
  `notarize.sh` passes `-Xswiftc -Xclang-linker -Xswiftc -isysroot …` and
  checks the recorded SDK. A plain `swift build` (README steps, debug runs)
  still records `sdk 14.0` — harmless for local use.
- **Telnet IAC noise.** Some AR-Cluster forks (e.g. N2WQ-2) prefix their banner
  with Telnet IAC option-negotiation bytes and use hanging (newline-less)
  prompts. `DXClusterClient.stripTelnetIAC` + the hanging-prompt path handle
  this; see comments there before touching auth detection.
- **`lsof` cannot see the cluster connections.** `NWConnection`
  (Network.framework) rides Apple's user-space networking stack (Skywalk),
  not BSD sockets — `lsof -i` on the app's pid shows only the `:7575`
  listener and its clients, never the outbound telnet sessions, even when
  they are live and streaming. Debug real flow state with
  `nettop -x -L 1 -p <pid>` (shows per-flow bytes in/out). Bit us on
  2026-08-24: an apparently-live badge with "no socket" was misread as a
  state bug when the tool was simply blind.

---

## Recent history

- **2026-10-09 (afternoon) — v1.8.7 released** (notarized + stapled,
  universal), carrying the two entries below. Manoj: *"release the mac app
  too"*, after dxca v2.23.0 had gone out with the same cluster-line change.
  https://github.com/vu2cpl/DXClusterAggregator-macOS/releases/tag/v1.8.7 —
  asset `DXClusterAggregator-1.8.7-notarized-universal.zip` (2,106,046
  bytes), SHA-256
  `814741cca541ff1622efa3ef0610a53d2193b3c0c367f61c6f14bfcd16c80a65`.
  Footer, `generate_manual.py` (PDF regenerated) and the README's
  `Info.plist` example bumped first; release commit `0ac3ecb`, annotated tag
  `v1.8.7`, both pushed. `./notarize.sh 1.8.7` ran clean end to end: SDK
  27.0, `minos 14.0`, both slices, key injected and cleared (the tree was
  checked clean before the commit), notary `Accepted`, stapled. The asset
  was downloaded back: sha256 equal, `ditto -x -k`, `codesign --strict`,
  `spctl` (Notarized Developer ID) and `stapler validate` pass, `x86_64
  arm64`, version 1.8.7, binary identical to the build. Installed over the
  1.8.6 copy at `/Applications/DXClusterAggregator.app` (not running before
  or after — dxca holds the ports). Release notes: the cluster line, the
  update dialog, the install paragraph, the VU3ESV credit. `releases/latest`
  answers v1.8.7.

- **2026-10-09 (released in v1.8.7) — relayed
  comments verbatim, decodes in RBN Aggregator's shape, at the dial.**
  Manoj asked whether the spots going to destinations carry the DF in the
  comment. They did not: `ClusterFormatter` synthesised `FT8 -10 dB` for
  every spot, so a relayed skimmer spot's `-15 dB 1032 FT8` left as
  `FT8 -15 dB` and the offset went with it. Three passes, none released: a
  labelled `FT8 -10 dB DF 1487 Hz` (commit `ea52176`); then, shown the
  inbound shapes, *"keep the original comment and no need for any DF or Hz
  in comments. the logging softwares are made to take it that way"*; then
  *"sequence it exactly like vu2oy format"*. VU2OY's node
  (`vu2oy.ddns.net:7550`) turned out to be **RBN Aggregator** (its banner
  says so), and its `6` is **FT8's symbol rate in baud** in the column a CW
  spot uses for WPM. Now: `SpotMessage` gained `comment: String?` (nil for
  decodes — the WSJT-X Decode message has no such field; `handleClusterSpot`
  fills it from the `DX de` line) and `cqGrid` (a CQ's trailing locator,
  `RR73` refused); `ClusterFormatter.format` sends a relayed comment
  verbatim (even empty) and gives a decode Aggregator's comment column for
  column — SNR `%3d`, ` dB`, rate `%4d` (FT8 `6`; FT4 `21`, 20.833 rounded,
  unverified against a live line), mode, two spaces, `CQ`/`CQ <grid>` in 8,
  offset `%4d`; 28 columns for a 3-letter mode, no rate token for modes
  Aggregator never spots, no offset column when `deltaFrequency` is 0. **The
  frequency cell is now the dial** (`dialFrequency`), as Aggregator spots
  it, with the offset in the comment relative to it; a decode used to go
  out at dial + offset (14075.8), which a logger reading the comment would
  count twice — this is the one change a logger notices. Feeds the telnet
  server and DX-cluster-text UDP destinations; the WSJT-X-format UDP
  builder and passthrough are untouched. dxca got the identical change the
  same night (`dxca-core/src/format.rs`; its HANDOVER, *Session 2026-10-09
  (night)*, has the Aggregator banner and the sample numbers). Verified:
  `swift build` clean apart from the pre-existing Combine warning in
  ContentView. Shipped in v1.8.7 the same afternoon, with the update-dialog
  change below.

- **2026-10-09 (released in v1.8.7) — update dialog:
  no focus, no default button for the automatic check.** Manoj's rule, as
  already applied to MSHV. The shared `UpdateChecker.swift` (still
  byte-identical in all the Swift apps) used an app-modal `NSAlert` brought
  forward with `NSApp.activate()`, so an automatic check's dialog became the
  key window mid-typing and Return pressed Download. It is now a non-modal
  panel: from an automatic check `orderFrontRegardless()` (in front, but the
  app is not activated and the panel is not key); from Check for Updates…
  activated and key. No default button either way (Return does nothing,
  Download needs a click), Esc / close box = Remind Me Later, the notes hold
  the keyboard when it is key, and the panel ends its responder chain for
  `performClick:` (AppKit sends that on Space; past a panel it reached the
  main window and "clicked" a text field there). Up-to-date / failure alerts
  unchanged (manual only). Verified: `swift build` and `swift build -c
  release` clean, no warnings in the file; a 41-check scratch harness in a
  real AppKit run loop (another app keeps the keyboard; this app's text field
  keeps typing and Return; Return/Space/Esc in the panel; a click on Download
  opens the intercepted URL; manual panel key with no default button). No
  new DXCA release for this (Manoj, 2026-10-09) — it rides along with the
  next one.

- **2026-10-09 — v1.8.6 released** (notarized + stapled, universal), the
  first release with the update check (both entries below).
  https://github.com/vu2cpl/DXClusterAggregator-macOS/releases/tag/v1.8.6 —
  asset `DXClusterAggregator-1.8.6-notarized-universal.zip`, SHA-256
  `7c1a2b10d51c9b5f785dee11ba64c236a246ba792487bc996dc03663a7dfa5dc`;
  downloaded back, unpacked with `ditto -x -k`, `codesign --strict`, `spctl`
  (Notarized Developer ID) and `stapler validate` pass, `x86_64 arm64`,
  version 1.8.6, binary identical to the build. Installed to
  `/Applications/DXClusterAggregator.app` (there was no copy there before;
  not launched — it was not running).
  **`notarize.sh` fixed first** — it no longer ran on this Mac: it demanded a
  macOS 15 SDK (only 26.5/27.0 installed) and copied from
  `.build/apple/Products/Release`, where Swift 6.4 no longer writes. It now
  uses the active Xcode's SDK, asks `swift build --show-bin-path`, deletes the
  old product and `.app` first, and fails loudly on a missing product, a
  missing architecture, the wrong `minos`/recorded SDK, an `@rpath` dylib, a
  copy that differs from the build, `codesign`/`spctl` failure, or AppleDouble
  entries in the zip (`ditto --norsrc`; v1.8.5's zip carried 23). The version
  now comes from (and must match) the `ContentView` footer. Also found:
  Swift 6.4 records `sdk 14.0` unless the linker is given `-isysroot` (see
  *Known gotchas*); this release records `sdk 27.0`, `minos 14.0`, where
  v1.8.5 recorded `sdk 26.5`. README build-from-source steps updated to the
  `--show-bin-path` form and the SDK-15 instruction dropped.

- **2026-10-09** (released in v1.8.6) — **Update check:
  Manoj's three follow-up decisions.** Changed once in the shared
  `UpdateChecker.swift` and copied whole to all five repos (still
  byte-identical). **(1) Only a successful check stores the time** — success
  is HTTP 200 whose JSON has a `tag_name`, newer or not. Every failure
  (offline, timeout, any HTTP error including the 403 rate limit, 404, bad
  JSON) writes nothing, so the next launch tries again; the 10-08 version also
  stored the time when GitHub answered with an error, so one rate-limited
  launch silenced the check for a day. While the app runs, a failed automatic
  attempt holds automatic attempts off for 1 h (in memory only); a failed
  manual check touches neither. **(2) Re-check while running** — this app
  runs for weeks, so after the launch check (still ~10 s after start) an
  hourly timer (5 min tolerance, counted from the end of each attempt) runs
  the automatic check when the setting is on, 24 h have passed since the last
  success, the 1 h back-off is over and none of the checker's dialogs is open
  — the pure `UpdateChecker.shouldCheckAutomatically(...)`. **(3) Development
  builds never check on their own** — a version containing "dev" (any case)
  makes no request at launch or from the timer; Check for Updates… still
  works, and `UPDATE_CHECK_TEST_CURRENT_VERSION` replaces the version as
  before and is not subject to the rule. Dialog, Skip / Remind Me Later,
  toggle and menu item unchanged. Verified without launching the app: debug
  and release builds clean, no warnings in the file; a scratch harness passed
  148 cases (timer decision, success/failure storage per failure kind,
  back-off, response parsing) with GitHub replaced by a stand-in, a fake
  `0.0.0-dev` bundle made no request while a release-version one made
  exactly one, and two live requests passed. README *Updates* and manual
  § 3.4 updated, PDF regenerated.

- **2026-10-08** (released in v1.8.6) — **In-app update
  check against GitHub releases.** Manoj's call for all five of his Swift apps:
  tell the user when a newer release is out, with no Sparkle, no appcast and no
  server of our own. New `DXClusterAggregator/UpdateChecker.swift` — one
  self-contained file, **byte-identical** across timesync-mac,
  DXClusterAggregator-macOS, kst2mac, macexpert-spe and AmateurRadioSuite (fix
  it in one, copy the whole file to the others); the per-app part is the
  `UpdateChecker.Configuration.app` extension in `DXClusterAggregatorApp.swift`.
  About 10 s after launch (`AppDelegate.applicationDidFinishLaunching`), at most
  once per 24 h, it sends one anonymous `GET
  api.github.com/repos/vu2cpl/DXClusterAggregator-macOS/releases/latest` (10 s
  timeout, no token) and compares `tag_name` with `CFBundleShortVersionString`
  as integer tuples. Newer → dialog with the release notes, **Download** (opens
  the release page; nothing is downloaded or installed) / **Skip This Version**
  / **Remind Me Later**. Automatic checks are silent on any failure and for a
  skipped tag. **Check for Updates…** sits in the app menu after About and
  always reports; the **Check for updates automatically** toggle (default on)
  is its own row in the settings panel under Callsign. UserDefaults keys
  `UpdateCheck.automatic` / `.lastCheck` / `.skippedTag`. Test hook, inert
  unless set: quit, `open --env UPDATE_CHECK_TEST_CURRENT_VERSION=0.0.1
  DXClusterAggregator.app`, then Check for Updates… shows the dialog against
  the real v1.8.5. Verified without launching the app (the dxca burn-in owns
  its ports): the checker read v1.8.5 from the live API, the version
  comparison and 24 h gate passed their cases, and the dialog was rendered
  off-screen. README (feature bullet, defaults table, *Updates* section) and
  manual § 3.4 added; PDF regenerated. An unbundled `swift run` build has no
  version number, so its manual check says so and its automatic one stays
  quiet.

- **2026-09-03** (unreleased, on `main`) — **The ClubLog developer API key now
  ships with the app, injected at build time.** Every new user used to hit a
  first-run hard stop: alerts need `cty.xml`, `cdn.clublog.org/cty.php` needs
  an API key, and that key had to be requested by hand and waited on. Club Log
  issue it per *application*, so it was the same value for everybody — friction
  for nothing. New `Utils/BuiltInCredentials.swift` (generated; tracked form
  holds an **empty** key) plus `ClubLogConfig.effectiveAPIKey`, which prefers a
  key typed into Settings and falls back to the built-in one, so anyone who
  would rather spend their own quota still can.
  **The key is never committed** — `notarize.sh` injects it for the release
  build and a `trap … EXIT` clears it again, verified against a simulated
  build failure (40 bytes present mid-build, 0 after, working tree clean).
  That is not caution for its own sake: Club Log's API Keys article says keys
  found published in a Git repository are deleted without notice, and this repo
  is public. See *Repo conventions* for the full reasoning and the rotation
  recipe. The Settings API Key field **stays, but moved** out of the main rows
  into a collapsed **Advanced** disclosure at the foot of the ClubLog section
  (`clubLogAdvanced`) — a released build makes it a leftover that mostly
  invites pasting the wrong secret in, but it is still the only route to a
  country file in a source build, the escape hatch if ClubLog ever revokes the
  shipped key, and the home of any key existing users already stored. The
  disclosure defaults **open** when no key is built in (`showClubLogAdvanced`),
  and its label carries a tag — "own API key set" (grey) or "API key needed"
  (orange) — so a collapsed row still says whether anything is in there.
  Placeholder and caption switch on the same `BuiltInCredentials
  .clubLogAPIKey.isEmpty`. README requirements + build-from-source notes and manual § 9.1/9.2
  reworded; PDF regenerated (which also fixed the App Password cell overflowing
  its column). Verified: the Swift de-obfuscation round-trips to the configured
  key, `cty.php` answers HTTP 200 + gzip for it, and the empty tracked form
  compiles and yields an empty string.
  **Same session — ClubLog 403 handling.** ClubLog ask that a rejected
  credential stop being sent immediately; the app treated 403 as just another
  non-200 and would happily send the same wrong key on every click of Refresh.
  New `ClubLogError` (403 kept separate from every other failure) and
  `ClubLogRejection` (a fingerprint latch, see *Repo conventions*), applied to
  both the cty key and the log credentials independently — a wrong app
  password says nothing about the API key. Status messages now name what to
  change rather than repeating "HTTP 403". Behaviour-checked: an untried key
  reads clean, a rejected one latches, a *different* key is unaffected, the
  two scopes are independent, a success clears, and ("ab","c") does not
  collide with ("a","bc"). **Note: this app has no automatic ClubLog refresh
  at all** — `autoRefreshOnStart` and `refreshIntervalHours` are in
  `ClubLogConfig` and wired to nothing, so the only caller is the Refresh
  button. The latch therefore guards against a human clicking, not a timer.
  **Released as v1.8.5** (notarized + stapled the same day),
  which is the version that first carries both this and the 403 latch.
- **2026-08-26** (docs) — Drafted the **DXCA 2.0 port plan**:
  [`docs/DXCA2-RUST-PLAN.md`](docs/DXCA2-RUST-PLAN.md). Design-only, nothing
  implemented. DXCA 2.0 is a standalone Rust + Svelte-web-GUI successor
  (working name `dxca`, private repo, not created yet) targeting a
  Raspberry Pi as primary host — the SkimServer-Mac→Meridian pattern. The
  DX-cluster telnet client/server engines get lifted from
  `~/projects/meridian` (`meridian-core/src/dxcluster/`, ~2.9k lines);
  new in Rust: the WSJT-X binary UDP codec, ClubLog/alert brain ports, and
  a **multi-user login layer** so each user has their own ClubLog
  credentials/matrix/alerts over one shared spot stream. The plan pins
  parity requirements on this repo's v1.8.x behaviour (honest status,
  passthrough, default ports) and an M6 dual-run validation against the
  Mac app. Once 2.0 ships, this repo enters maintenance mode.
- **v1.8.4** — Size cap on the on-disk spot log. `SpotLogger` appended pruned
  spots to `DXC Spots.txt` forever with no rotation — the live file had
  reached **520 MB**. Now `SpotLogger.append(_:maxMB:)` enforces a cap after
  every append: when the file exceeds it, the newest ~75% of the cap is kept
  (whole lines, seek-from-end so the old bulk is never read into memory) and
  rewritten atomically with the header restored; 75% rather than 100% gives
  hysteresis so the rewrite runs once every few days, not per append. New
  setting `spotLogMaxMB` (default 100, range 0–1024, 0 = unlimited/old
  behaviour) follows the `autoClearMinutes` @AppStorage + clamped-string-
  binding pattern; UI is a "Spot Log Cap" field in the configuration row next
  to TCP Cluster Port. An existing oversized file self-heals on the first
  prune/clear after upgrade (520 MB → ~75 MB in one trim). Manual §
  "Auto-Clear + Spot Log File" extended; PDF regenerated.
- **v1.8.3** — Fix phantom fail counter for passthrough destinations.
  v1.8.2's per-spot `broadcast()` appended the destination to `attemptedIds`
  *before* the format switch, and the `.passthrough` case `continue`d without
  writing a result — so every aggregated spot booked a failure against the
  passthrough destination (`UDP→: n (fails m)` climbing forever, live send
  path unaffected). The passthrough skip now happens at the top of the loop,
  before any bookkeeping. Spotted live within minutes of deploying v1.8.2:
  status bar read `UDP→: 144 (fails 74)` while RUMlog was receiving
  everything (click-to-fill verified working from all three decoders).
- **v1.8.2** — UDP passthrough. Adds a third broadcast destination format
  (alongside `cluster` and `wsjtx`): **Passthrough** forwards every raw
  incoming UDP datagram from allowed sources verbatim to the destination,
  without parsing or per-spot re-emit. Restores RUMlogNG's click-to-fill
  callsign lookup, which relied on WSJT-X-family Status updates (fired when
  the operator clicks a decoded callsign in the decoder's list) reaching the
  logger — DXCA's aggregated `wsjtx` format synthesises Status+Decode pairs
  per spot and doesn't relay upstream Status messages, so click-to-fill went
  silent when decoders were pointed at DXCA instead of RUMlog directly.
  Implementation: new `.passthrough` case in `UDPBroadcastFormat`; new
  `UDPBroadcaster.sendRaw(data:sourceName:)` iterating passthrough
  destinations only; new `WSJTXUDPListener.onRawDatagram` callback fired
  before parsing; orchestrator in `ContentView.startMonitoring()` wires the
  callback to the broadcaster; Picker gets a "Passthrough" option with a
  tooltip. When a passthrough destination and a `wsjtx` destination both
  point at the same host:port, the `wsjtx` path skips the emit (see the
  `continue` in the `broadcast` switch) — passthrough already carries the
  original datagrams, so double-emit is prevented at the switch.
- **2026-08-26** (docs) — Added [`docs/UDP-PIPELINE.md`](docs/UDP-PIPELINE.md)
  documenting the full MSHV + JTDX + WSJT-X + RUMlogNG + DXCA wiring with
  screenshots (`docs/images/udp-pipeline/*.png`), covering per-app config,
  port allocation, why "Simplified UDP Broadcast" is a separate path for
  MSHV → RUMlog QSO logging, reboot-race troubleshooting, and the
  `lsof`/Skywalk blindness caveat. Motivated by a post-OS-update hang where
  RUMlogNG's login-item raced DXCA to bind UDP 2237 — reproducible any time
  two apps compete for the same WSJT-X port; the canonical topology removes
  every collision by giving each decoder a distinct DXCA input port.
- **v1.8.1** — Status cell → clickable pill (operator feedback on v1.8.0:
  fonts too small; wanted the shack Vue dashboard's pill style — indicator
  and button in one). `ClusterStatusCell` is now a tinted capsule (11.5 pt
  semibold mono, up from `.caption2`) whose colour carries the state
  (green proven-live / yellow unproven / orange down) and whose text carries
  the activity — live pills show "count · last-spot age" (self-updating,
  count compacted ≥1k), yellow shows "no spots", orange shows
  "connecting"/"retry Ns" (compacted from the fuller `statusText`, which
  the hover tooltip still shows in full). **Clicking the pill drops the
  session and redials immediately** (`DXClusterClient.recycleNow()` —
  resets backoff, no-op when monitoring is stopped); status column widened
  120 → 135. v1.8.0's watchdog was verified live before this: VE7CC's
  dead-login session was auto-recycled (source port rotated) exactly on
  schedule. Manual §6.2 rewritten around the pill; PDF regenerated.
- **v1.8.0** — Honest cluster status + self-healing sessions. Motivated by the
  2026-08-24 VE7CC outage (its login layer went silently dead: TCP + banner
  fine, every callsign ignored) — the app showed "Connected" for a session
  receiving nothing. (Diagnostic footnote: `lsof` shows NO sockets for the
  cluster connections — `NWConnection` uses user-space networking (Skywalk),
  invisible to fd-based tools; only the BSD-bound `:7575` listener appears.
  Use `nettop -x -L 1 -p <pid>` to see the real flows. An earlier "badge
  survives with no socket" observation was this blindness, not an app bug.)
  Four changes: **(1)** three-state badge — green only when *proven
  live* (login welcome ack **or** first parsed spot, which also covers
  no-login ports like VU2OY/skimmer feeds), yellow = TCP up but unproven (the
  dead-login trap state), orange = down/reconnecting; **(2)** per-source
  **spot count + self-updating "last spot" age** in the status cell (SwiftUI
  `Text(_, style: .relative)`); **(3)** two bug fixes — server-initiated
  close (`isComplete` in `receiveData`) never scheduled a reconnect,
  stranding the client until monitoring restart, and the status row read
  client state through a plain `@State` dictionary without observing it, so
  badges only refreshed when something unrelated redrew (fixed with an
  `@ObservedObject` `ClusterStatusCell` subview); **(4)** a 30s session-health
  watchdog — connected-but-unproven for 120s → recycle (backoff escalates
  because `reconnectAttempt` now resets on *proven-live*, not on TCP `.ready`,
  so a dead-login cluster settles at a 5-min retry instead of parking forever
  or hammering), and proven-live-but-silent for 15 min → recycle (catches
  half-open sockets TCP never flags). Status-bar `DX: n/m` green count now
  counts proven-live sources.
- **v1.7.6** — Fix minimised-window restore: both `WindowManager.showMainWindow`
  and `applicationShouldHandleReopen` now call `deminiaturize(nil)` when the
  window is sitting in the Dock as a thumbnail. Previously `makeKeyAndOrderFront`
  alone only reordered z-stack, leaving the window minimised — the menu-bar
  "Show Window" entry appeared to do nothing. (Note: does **not** cover the
  case where a display-topology change during an OS update leaves the saved
  window frame off-screen or dropped entirely; observed 2026-08-26. A
  hardening pass in `WindowManager` to re-create the window when none exists
  is a separate open item.)
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

- ~~**Before the next release, check `notarize.sh` against today's
  toolchain**~~ — **done 2026-10-09** with v1.8.6: no SDK-15 pin, product path
  from `--show-bin-path`, fresh build enforced and verified (see *Recent
  history*). Still Manoj's call if he wants it: a launch test on a real
  macOS 14/15 machine, which nobody has done since the SDK question was
  raised in April.
- **DXCA 2.0 (Rust port) — M2 complete; ⚠️ dxca is running the shack in
  burn-in since 2026-08-27.** The successor repo:
  https://github.com/vu2cpl/dxca (local `~/projects/dxca`; the plan's
  canonical copy is `docs/PLAN.md` there, this repo's
  [`docs/DXCA2-RUST-PLAN.md`](docs/DXCA2-RUST-PLAN.md) is the original
  draft). Milestones so far: M0 scaffold + Pi binary verified on
  noderedpi4; M1 core-logic ports with exact parity against this app's
  own matrix.json; M2 spot path validated live — dxca took over ports
  2333/2334/2335 + 7575 on the Mac, RUMlog populated and click-to-fill
  worked. M3 same day: the Meridian-lifted cluster client with the 1.8.x
  honest-status graft ingests all five shack nodes in the burn-in (four
  proven Live immediately, VE7CC honest-yellow). **While the burn-in runs,
  this 1.x app must stay closed** (port clash) — it is the standing
  fallback (`pkill -f target/release/dxca`, relaunch the app). 1.x fixes
  still land here and inform the 2.0 parity spec. M4 and all of M5 same
  day: SQLite users + per-user ClubLog matrices + Telegram fan-out, the
  live WebSocket dashboard (spots table, filters, status pills, LoTW
  markers), and web config editing with hot-apply — the browser now
  covers the daily-driver workflow including sources/nodes/destinations
  management. Manoj's admin account exists on the burn-in. **M6 done same day:
  v2.0.0 tagged + released** (binaries attached), the Mac runs it as a
  launchd agent, and noderedpi4 (192.168.1.169) has it installed as a
  systemd service, standing by. The decoder cutover completed the
  same evening — **production DXCA is the Pi**; this repo is in
  maintenance mode (README banner, UDP-PIPELINE current-wiring
  section). Rollback path: stop the Pi service, decoders back to
  127.0.0.1, launch this app.
- **Window restore after display-topology change.** `WindowManager` currently
  deminiaturizes an existing window (v1.7.6 fix), but doesn't handle the case
  where the SwiftUI-managed window has been dropped entirely — e.g. after an
  OS update whose reboot changes the display arrangement and the saved frame
  lands off-screen or the scene state is discarded. Observed on 2026-08-26:
  menu-bar "Show Window" was a no-op. Workaround: quit and relaunch the app.
  Fix: `showMainWindow` should re-create the window (via `NSApp.windows`
  scan → `openWindow(id:)` or an explicit `NSWindow` init) when none exists,
  not only reorder/deminiaturize.
- **DXCA's *parser* drops WSJT-X type-5 (QSO Logged) and type-12 (ADIF
  Log) — but passthrough does not, and that is the part that matters.**
  `WSJTXUDPListener.processMessage` handles only `.status` and `.decode`;
  everything else falls into `default: break`. **Corrected 2026-08-28:**
  this entry used to conclude that logged QSOs therefore had to reach
  RUMlog by a separate ADIF-over-UDP leg on `127.0.0.1:2233` (MSHV
  *Simplified UDP Broadcast*, JTDX *2nd UDP server*, WSJT-X *Secondary UDP
  Server*). They don't. Passthrough relays each datagram **verbatim before
  parsing**, so type-5 reaches RUMlog's Data Port (2237) and its *Save QSOs
  to logbook* files it. In practice the only decoder-side setting needed is
  MSHV's **Enable Logged QSO** (its main broadcast gates message types
  individually and ships with that box off); JTDX and WSJT-X emit logged
  QSOs on the primary UDP server unconditionally. Established by operating
  the shack, not by reading the code — the code had said as much all along
  and the doc argued both sides. Full write-up:
  [`docs/UDP-PIPELINE.md`](docs/UDP-PIPELINE.md) § *Logged QSOs need no
  second feed*. Fixing the parser would still only matter if QSO logs
  needed to be *fanned out* to a second logger.
- `SpotMessage.dxCallsign`'s `looksLikeCallsign` heuristic is defensive but not
  exhaustive — pathological FT8 messages could still slip a non-call into the
  callsign column. Revisit if a user reports it.
- `stripTelnetIAC` drops trailing partial IAC sequences that span packet
  boundaries. Harmless in practice (clusters emit the IAC preamble in one
  initial segment); revisit if a cluster interleaves IAC commands mid-session.
