# The Shack UDP Pipeline — MSHV + JTDX + WSJT-X → DXCA → RUMlogNG

> ## ⚡ Current wiring (since 2026-08-27): DXCA 2.0 on noderedpi4
>
> The aggregator is now **dxca v2.0.0** (Rust, repo `vu2cpl/dxca`) running
> as a systemd service on **noderedpi4 (192.168.1.169)**. Same pipeline
> shape, one IP change:
>
> | Leg | Now |
> |---|---|
> | MSHV UDP Broadcast | `192.168.1.169:2333` |
> | JTDX primary UDP | `192.168.1.169:2334` |
> | WSJT-X UDP server | `192.168.1.169:2335` |
> | Decoder ADIF (QSO logs) → RUMlog | **not needed — see below.** Logged QSOs ride the ordinary decoder feed through dxca's passthrough |
> | dxca passthrough → RUMlog Data Port | `192.168.10.226:2237` (the Mac) |
> | RUMlog DX Cluster tab / any logger | `192.168.1.169:7575` |
> | Web dashboard + config | `http://192.168.1.169:7580` |
>
> Sources, cluster nodes, and destinations are edited in the web UI
> (System tab, hot-applies). Service ops on the Pi:
> `systemctl status/restart dxca`.
>
> **Everything below documents the 1.x-era wiring (decoders →
> 127.0.0.1, this macOS app as aggregator). It is kept as the fallback
> runbook**: to roll back, stop the Pi service
> (`sudo systemctl stop dxca`), point the decoders and RUMlog back at
> `127.0.0.1` per the sections below, and launch DXClusterAggregator.app.

Wiring three FT8/FT4 decoders (MSHV, JTDX, WSJT-X) and a logger (RUMlogNG) so
they run **simultaneously**, share every decoded spot, and don't fight over UDP
ports at reboot.

This has been a recurring pain point (post-OS-update in particular): apps race
to bind port 2237 at login, one wins, everyone else silently fails, and it
looks like "the aggregator is hung". This doc is the canonical wiring — follow
it and the whole graph starts up in any order without clashes.

> **v1.8.2 update:** the RUMlog broadcast destination is now **Passthrough**
> instead of *WSJT-X UDP*. Passthrough forwards every incoming decoder
> datagram to RUMlog verbatim, which preserves the WSJT-X Status stream —
> including the click-to-fill Status updates that fire when the operator
> selects a callsign in a decoder's list. The old *WSJT-X UDP* format
> synthesised one Status+Decode pair per aggregated spot and stripped
> everything else, which silently broke RUMlog's callsign auto-fill / QRZ
> lookup for anyone routing decoders through DXCA. If you're on v1.8.1 or
> earlier, change the format to Passthrough after upgrading.

## The rule that makes this work

**DXClusterAggregator (DXCA) is the sole listener on every WSJT-X port.**
Every decoder targets a distinct DXCA input port. DXCA then forwards each
datagram verbatim (Passthrough) to the port RUMlog listens on. No two
processes ever try to bind the same port, and every WSJT-X message type
(Status, Decode, Heartbeat, Clear, QSO Logged, …) reaches RUMlog intact.

## Topology

Each decoder sends **one** stream: its ordinary WSJT-X feed to DXCA on its own
port. Logged QSOs are *part of that stream* (WSJT-X type-5), and passthrough
carries them to RUMlog along with everything else — so there is no second
ADIF-over-UDP leg to configure. See [Logged QSOs need no second
feed](#logged-qsos-need-no-second-feed).

```
   MSHV  ───────── UDP :2333 ───►  DXCA "MSHV" source
   JTDX  ───────── UDP :2334 ───►  DXCA "JTDX" source
   WSJT-X ──────── UDP :2335 ───►  DXCA "WSJTX" source

        (decodes, status AND logged QSOs — one socket each)

                                       ┌─►  TCP :7575  (local cluster server)
                                       │     RUMlogNG "DX Cluster" tab
                                       │     Logger32, N1MM+, Log4OM, MiniM4 Pro, …
   DXCA aggregates all decoders ───────┤
                                       │
                                       └─►  UDP :2237  (Passthrough — every raw
                                             WSJT-X datagram forwarded from all
                                             sources verbatim: decodes, the
                                             click-to-fill Status stream, and
                                             logged QSOs)
                                             RUMlogNG "Data Port" (WSJT-X section)
```

## Port allocation

| Port  | Direction               | Producer                 | Consumer               | Wire format          |
|-------|-------------------------|--------------------------|------------------------|----------------------|
| 2333  | UDP → 127.0.0.1         | MSHV (decodes)           | DXCA "MSHV" source     | WSJT-X binary        |
| 2334  | UDP → 127.0.0.1         | JTDX (decodes)           | DXCA "JTDX" source     | WSJT-X binary        |
| 2335  | UDP → 127.0.0.1         | WSJT-X (decodes)         | DXCA "WSJTX" source    | WSJT-X binary        |
| 2237  | UDP → 127.0.0.1         | DXCA passthrough         | RUMlogNG WSJT-X input  | WSJT-X binary (raw)  |
| 7575  | TCP LISTEN              | DXCA                     | Any DX cluster client  | Cluster telnet lines |

No port appears in the "Consumer" column twice. That is the invariant.

**Port 2233 is no longer part of this pipeline.** Earlier revisions of this
doc routed each decoder's logged-QSO ADIF there, to RUMlog's "QSOs received
from Flex / ADIF" listener. That leg was always redundant — see [Logged QSOs
need no second feed](#logged-qsos-need-no-second-feed) — and the shack does
not use it. Nothing breaks if you leave an old 2233 configuration in place;
RUMlog would simply log each QSO from whichever path arrives first, and
ignore the duplicate.

## Per-app configuration

### 1. DX Cluster Aggregator

Open **Show Settings** on the main window.

![DXCA settings — UDP sources and broadcast destination](images/udp-pipeline/02-dxca-settings.png)

> Screenshot pre-dates v1.8.2 and shows Destination 1's Format as *WSJT-X U…* —
> on v1.8.2 or later, change it to **Passthrough** for the reason explained
> in the callout at the top of this doc.

- **TCP Cluster Port:** `7575` (do not use 7550 — SkimSrv defaults to it).
- **UDP Sources (WSJT-X / JTDX)** — three rows, `127.0.0.1` on all:
  - `MSHV 2333` — port `2333`
  - `JTDX 2334` — port `2334`
  - `WSJTX 2335` — port `2335`
  All three Enabled. Status should read **Active** once services are up.
- **Broadcast Destinations** — one row:
  - Name `Destination 1`, IP `127.0.0.1`, Port `2237`, Format
    **Passthrough**, Sources **All**, **On ✓**. *(The Unf flag doesn't
    apply to Passthrough — it forwards every raw datagram regardless.)*

That destination forwards every incoming datagram from every enabled UDP
source verbatim to 127.0.0.1:2237. RUMlog receives the decoders' native
WSJT-X Status/Decode/... stream unchanged, so the click-to-fill callsign
lookup works exactly as if the decoder were pointed at RUMlog directly.

> If you also want an aggregated / deduplicated spot stream to a *separate*
> tool (e.g. an RBN uploader), add a second broadcast destination on a
> different port using the **WSJT-X UDP** format — the two paths coexist
> because Passthrough entries skip the per-spot synthesis path (see the
> `continue` in `UDPBroadcaster.broadcast`) and vice-versa.

![DXCA main window — live monitoring](images/udp-pipeline/01-dxca-main.png)

Live status bar reads e.g. `Monitoring · UDP: 3/3 · DXC: 4/5 · TCP: 1
client(s) · UDP→: 617` — three UDP sources proven live, four of five cluster
nodes proven live, one logger connected on 7575, 617 spots forwarded out via
UDP broadcast.

### 2. MSHV

Menu → **Options → Network Configuration** → *Network Configuration* tab.

![MSHV Network Configuration — UDP Broadcast and Simplified UDP Broadcast](images/udp-pipeline/03-mshv-network-config.png)

**MSHV is the only one of the three that needs anything beyond its port.**

- **UDP Broadcast Settings** (the WSJT-X-compatible binary feed):
  - Server `127.0.0.1`, Port `2333`
  - **Enable Decoded Text** ✓ (the spots)
  - **Enable Logged QSO** ✓ ← **tick this.** It is what puts your logged
    QSOs on the same socket, so passthrough carries them to RUMlog. MSHV
    ships with it off, and it is the single setting people miss.
  - **Enable Logged QSO ADIF** ✗ (type-12; RUMlog reads the type-5 above)

  Status line should turn green: `Connected to localhost IP 127.0.0.1`.

- **Simplified UDP Broadcast** — **not needed.** Leave it off. See [Logged
  QSOs need no second feed](#logged-qsos-need-no-second-feed).

### 3. JTDX

**JTDX menu → Preferences...** → **Reporting** tab.

![JTDX Reporting — Primary UDP Server + 2nd UDP server for ADIF](images/udp-pipeline/05-jtdx-reporting.png)

Only one output to set:

- **Primary UDP Server** (bottom half, feeds DXCA):
  - UDP Server: `127.0.0.1`
  - UDP Server port number: `2334`
  - ✓ Accept UDP requests

That is the whole JTDX configuration. Unlike MSHV there is no checkbox to
tick for logged QSOs — JTDX puts them on the primary UDP server itself.

- **2nd UDP server / *Enable sending to secondary UDP*** — **not needed.**
  Leave unchecked. Same for the TCP server row: nothing on this shack
  listens on JTDX's ADIF-over-TCP.

### 4. WSJT-X

**WSJT-X menu → Preferences...** → **Reporting** tab.

![WSJT-X Reporting — UDP Server + Secondary UDP Server for ADIF](images/udp-pipeline/06-wsjtx-reporting.png)

Same single-output pattern as JTDX:

- **UDP Server** (feeds DXCA):
  - UDP Server: `127.0.0.1`
  - UDP Server port number: `2335`
  - Outgoing interfaces: `lo0` (loopback only — no packets on the LAN)
  - Multicast TTL: `1` (unused here; we're not multicasting)

That is the whole WSJT-X configuration — logged QSOs go out on this server
with everything else.

- **Secondary UDP Server (deprecated)** — **not needed.** Leave *Enable
  logged contact ADIF broadcast* unchecked. WSJT-X itself labels the section
  deprecated, and this pipeline never needed it.

### 5. RUMlogNG

**RUMlogNG → Preferences** (`⌘,`) → **UDP** tab.

![RUMlogNG UDP preferences](images/udp-pipeline/04-rumlog-udp-prefs.png)

- **WSJT-X** section (bottom-left):
  - ✓ Save QSOs to logbook  ← **this is what logs your QSOs.** It acts on
    the type-5 QSO-Logged messages arriving on the Data Port below, which
    is why no separate ADIF feed is needed.
  - ✓ Callsign check
  - ✓ Populate dx-spot table
  - ✓ Colorize callsigns
- **Data Port** (bottom-right): `2237`  ← receives DXCA's rebroadcast:
  decodes, Status, and logged QSOs alike.
- **Multicast:** leave *empty* (we are using unicast forwarding through DXCA;
  no multicast group is involved).
- **QSOs received from Flex / ADIF:** not used by this pipeline. Harmless to
  leave configured; nothing sends to it.
- **QSOs received from N1MM:** `Nil`, Port `2237` (the row is disabled by
  the Nil action — the port field being 2237 is cosmetic and does not open a
  second listener; the WSJT-X `Data Port` above is the one that binds).

Also configure **DX Cluster** in RUMlogNG's separate DX Cluster tab to point
at `127.0.0.1:7575` — that pulls cluster spots from DXCA's TCP cluster server.

## Logged QSOs need no second feed

*(Corrected 2026-08-28, from operating the shack. This section previously
argued the opposite — that each decoder needed a secondary ADIF-over-UDP leg
to `127.0.0.1:2233`. It doesn't, and the reason is worth writing down,
because the old argument looked airtight.)*

**The claim:** the only setting any of the three decoders needs beyond its
DXCA port is MSHV's **Enable Logged QSO**. No secondary / 2nd / Simplified
UDP broadcast, anywhere.

**Why it works.** Passthrough forwards each inbound datagram **verbatim,
before parsing** — that is the whole point of the format, and [The rule that
makes this work](#the-rule-that-makes-this-work) says as much: *every* WSJT-X
message type reaches RUMlog intact, QSO Logged included. A logged QSO is
WSJT-X **type-5**, arriving on the same socket as the decodes; DXCA relays it
to RUMlog's Data Port (2237), where **✓ Save QSOs to logbook** files it.
In dxca 2.0 this is `UDPBroadcaster::send_raw`, called on the raw bytes
before `wsjtx::parse` is ever reached; in 1.x it was the `onRawDatagram`
wiring, which behaved the same way.

**Why the old argument was wrong.** It observed — correctly — that DXCA's
*parser* drops types 5 and 12 (`default: break` in
[`WSJTXUDPListener.processMessage`](../DXClusterAggregator/Network/WSJTXUDPListener.swift);
`Message::Status`/`Message::Decode` only, in 2.0's `pipeline.rs`) and
concluded no downstream consumer ever sees them. But the parse path is not
the only path: passthrough had already copied the datagram out. The doc
contradicted itself for months — the rule at the top said QSO Logged reaches
RUMlog, this section said it couldn't — and the secondary feeds papered over
the gap, so nothing ever looked broken.

**Why only MSHV needs a tick.** MSHV's main broadcast gates each WSJT-X
message type behind its own checkbox, and *Enable Logged QSO* ships **off**:

| Checkbox                | WSJT-X message | Needed? |
|-------------------------|----------------|---------|
| Enable Decoded Text     | type-2 Decode  | ✓ — the spots |
| Enable Logged QSO       | type-5 QSO Log | ✓ — **the tick people miss** |
| Enable Logged QSO ADIF  | type-12 ADIF   | ✗ — RUMlog reads the type-5 |

JTDX and WSJT-X have no such gate: their primary UDP server emits logged
QSOs along with decodes and status, unconditionally. Hence "tick one box in
MSHV, and nothing else anywhere".

> **Note on the screenshots below and above:** they were captured under the
> old two-feed wiring, so MSHV's *Enable Logged QSO* shows unticked and the
> secondary-UDP panels show populated. The text is authoritative; the images
> are stale until re-shot.

## Reboot survival

Every port is bound by exactly one process:

- 2333/2334/2335 — only DXCA listens (each decoder is a *sender*, not a listener).
- 2237 — only RUMlogNG listens (DXCA is a sender to it).
- 7575 — only DXCA listens.

If any two of these apps race at boot, none of their `bind()` calls can
collide because they are targeting disjoint ports. The pathological old
setup (MSHV, DXCA and RUMlog all listening on 2237) is impossible in this
arrangement.

## Troubleshooting

### "The aggregator is hung after a reboot"

Usually not the aggregator — usually a bind race. Check who owns each port:

```bash
lsof -iTCP:7575 -sTCP:LISTEN
lsof -iUDP:2237
lsof -iUDP:2333
lsof -iUDP:2334
lsof -iUDP:2335
```

If DXCA is running but a `lsof -iUDP:...` for one of the 2333/2334/2335 ports
shows a different process holding it, that's the bind race. The fix is a
one-time port juggle (that other process should move off), then the
canonical DXCA layout survives every subsequent reboot.

**Caveat:** DXCA's WSJT-X listener uses Apple's Network.framework
(`NWListener`), which the modern macOS Skywalk stack keeps invisible to
`lsof` on some releases. If `lsof -iUDP:2333` shows no owner but MSHV's
status line says `Connected to localhost` and DXCA's source row shows
`Active` with a rising spot count, the listener is fine — `lsof` just can't
see it. Trust the app UIs over `lsof` in that case.

### "MSHV row in DXCA shows Active but 0 spots"

Verify **Enable Decoded Text ✓** in MSHV's *main* UDP Broadcast (port 2333),
not the Simplified one. Only the main feed carries decodes; Simplified is
logged-QSO ADIF only.

### "Spots flow fine, but MSHV QSOs never reach the log"

Tick **Enable Logged QSO** in MSHV's *main* UDP Broadcast. It ships off, and
without it MSHV simply never emits the type-5 message that carries the QSO —
so passthrough has nothing to forward. This is the one MSHV-specific setting
in the whole pipeline; JTDX and WSJT-X send logged QSOs unprompted. Confirm
RUMlog has **✓ Save QSOs to logbook** on its Data Port (2237) side.

### "RUMlog's WSJT-X ingest is empty"

- Is DXCA running and does its status bar show `UDP→: <nonzero>`? If not,
  DXCA isn't rebroadcasting.
- Is RUMlog's WSJT-X **Data Port** set to `2237`?
- Test the forwarding path from a terminal:
  ```bash
  nc -zv 127.0.0.1 7575     # DXCA cluster server (TCP)
  ```
- If DXCA's `TCP: N client(s)` is nonzero when RUMlog is running with its DX
  Cluster tab connected, the cluster path is working; a still-empty WSJT-X
  ingest means the UDP broadcast row in DXCA settings needs a re-check
  (**On ✓, Unf ✓, All sources**).

### "Both cluster spots and WSJT-X spots appear in RUMlog's DX Spots and I see duplicates"

Expected: RUMlog receives the same spot twice, once via its cluster tab
(from DXCA's TCP :7575) and once via the WSJT-X UDP path (DXCA's Passthrough
on :2237). If duplication is annoying, disable **Populate dx-spot table**
under WSJT-X in RUMlog to let the cluster path be the sole feed, or leave
WSJT-X on and disconnect RUMlog's DX Cluster tab from DXCA. Either is fine;
pick one and stick to it.

### "Clicking a callsign in WSJT-X/JTDX/MSHV doesn't auto-fill RUMlog's callsign field any more"

You're on DXCA v1.8.1 or earlier — the broadcast destination format is
*WSJT-X UDP*, which synthesises Status+Decode pairs per spot and drops
the original Status stream (including the click-to-fill updates). Upgrade
to v1.8.2 and change the destination Format to **Passthrough**.

## Version notes

- **DXCA v1.8.2** added the **Passthrough** broadcast format. Before v1.8.2
  the only WSJT-X-format option was the aggregated per-spot synthesis path,
  which stripped user-selection Status updates and broke RUMlog's
  click-to-fill callsign lookup. If you're on v1.8.1 or earlier and using
  the "decoders → DXCA → RUMlog" topology, upgrade and change your RUMlog
  broadcast destination's Format to **Passthrough**.
- DXCA v1.8.1 made the source status a clickable pill.
- DXCA v1.8.0 introduced honest cluster-status reporting (three-state badge,
  proven-live counters in the status bar), which is what lets you tell at a
  glance whether the UDP path is actually delivering.
- The v1.7.5 launch migration bumped any stored TCP cluster port from
  `7550 → 7575` (Skimmer clash). Existing installs from before v1.7.5 pick
  up 7575 automatically on first launch.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — cold-start dev doc.
- [`../README.md`](../README.md) — end-user overview and build instructions.
- [`../DXClusterAggregator_UserManual.pdf`](../DXClusterAggregator_UserManual.pdf) — printable manual.
