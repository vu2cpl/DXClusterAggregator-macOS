# HANDOVER — DXClusterAggregator for macOS

Cold-start doc for picking this project back up. If you read only one file
to get oriented, read this one. Pairs with `README.md` (end-user facing) and
the in-app About line.

**Current version:** v1.8.3
**Last updated:** 2026-08-26
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

- **Multi-app UDP topology (MSHV + JTDX + WSJT-X + RUMlogNG + DXCA):** the
  canonical wiring is documented in
  [`docs/UDP-PIPELINE.md`](docs/UDP-PIPELINE.md) — with screenshots of every
  panel. The rule: DXCA is the sole listener on every WSJT-X port; each
  decoder targets a distinct DXCA input port (2333 MSHV / 2334 JTDX / 2335
  WSJT-X); DXCA rebroadcasts every spot in WSJT-X wire format to
  `127.0.0.1:2237` where RUMlog's WSJT-X Data Port picks it up. MSHV also
  runs a **Simplified UDP Broadcast** to `127.0.0.1:2233` (raw ADIF) which
  RUMlog consumes on its "QSOs received from Flex / ADIF" listener — the
  *only* working MSHV → RUMlog logged-QSO path, because DXCA's
  `WSJTXUDPListener.processMessage` drops WSJT-X type-5 / type-12 in its
  `default: break`. This setup survives any reboot order (every port has
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

- **SDK-26 launch failure (Tahoe).** Building with the system-default SDK 26
  produces a binary that won't launch on macOS 15/earlier. Always pin
  `SDKROOT=.../MacOSX15.sdk` for release builds. (Both `MacOSX15.sdk` and
  `MacOSX15.4.sdk` are installed under `/Library/Developer/CommandLineTools/SDKs/`.)
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

- **DXCA 2.0 (Rust/Pi port) — M0 scaffolded 2026-08-26.** The private repo
  exists: https://github.com/vu2cpl/dxca (local `~/projects/dxca`), with the
  workspace, embedded-web-UI server stub, green local gate, and a proven
  aarch64 cross-compile. The plan's canonical copy moved there
  (`docs/PLAN.md`); this repo's [`docs/DXCA2-RUST-PLAN.md`](docs/DXCA2-RUST-PLAN.md)
  is the original draft. M0 closed same day — the cross-compiled binary ran
  on noderedpi4 (status API + embedded UI verified). Next: M1 (WSJT-X codec
  port with captured test vectors). Until 2.0 ships, this repo
  remains the production DXCA and normal fixes continue to land here (and
  inform the 2.0 parity spec).
- **Window restore after display-topology change.** `WindowManager` currently
  deminiaturizes an existing window (v1.7.6 fix), but doesn't handle the case
  where the SwiftUI-managed window has been dropped entirely — e.g. after an
  OS update whose reboot changes the display arrangement and the saved frame
  lands off-screen or the scene state is discarded. Observed on 2026-08-26:
  menu-bar "Show Window" was a no-op. Workaround: quit and relaunch the app.
  Fix: `showMainWindow` should re-create the window (via `NSApp.windows`
  scan → `openWindow(id:)` or an explicit `NSWindow` init) when none exists,
  not only reorder/deminiaturize.
- **DXCA drops WSJT-X type-5 (QSO Logged) and type-12 (ADIF Log) datagrams.**
  `WSJTXUDPListener.processMessage` handles only `.status` and `.decode`;
  everything else falls into `default: break`. Not currently a problem —
  every decoder has its own ADIF-over-UDP path to RUMlog (MSHV *Simplified
  UDP Broadcast*, JTDX *2nd UDP server*, WSJT-X *Secondary UDP Server*),
  all targeting `127.0.0.1:2233`, bypassing DXCA entirely. Would only
  become worth fixing if someone wants QSO logs to flow through DXCA
  specifically (e.g. to fan them out to a second logger). See
  [`docs/UDP-PIPELINE.md`](docs/UDP-PIPELINE.md) for the current wiring.
- `SpotMessage.dxCallsign`'s `looksLikeCallsign` heuristic is defensive but not
  exhaustive — pathological FT8 messages could still slip a non-call into the
  callsign column. Revisit if a user reports it.
- `stripTelnetIAC` drops trailing partial IAC sequences that span packet
  boundaries. Harmless in practice (clusters emit the IAC preamble in one
  initial segment); revisit if a cluster interleaves IAC commands mid-session.
