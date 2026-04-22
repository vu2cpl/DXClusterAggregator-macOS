# DXClusterAggregator for macOS

A native macOS application that aggregates FT8/FT4 spots from multiple WSJT-X/JTDX instances and DX Cluster nodes into a unified telnet cluster server.

## Features

- **Multiple UDP Sources** — Connect to several WSJT-X/JTDX instances simultaneously
- **DX Cluster Nodes** — Telnet DX cluster servers with auto-authentication and **auto-reconnect** (10s → 30s → 60s → 120s → 5 min backoff)
- **ClubLog Integration** — Download your log and highlight spots for **New DXCC / New Slot / New Band / New Mode** (configurable)
- **LoTW User Marker** — Green dot after callsigns of known LoTW uploaders (downloaded from ARRL directly)
- **Beacon Detection** — NCDXF/IBP + national beacon database; `/B` `/BCN` suffix handling; no false alerts
- **Digital modes grouped as DATA** — FT8/FT4/RTTY/JT65/PSK/MSK144 etc. share one DXCC slot, matching award rules
- **Built-in Telnet Cluster Server** — Feed aggregated spots to Logger32, N1MM+, Log4OM, DXKeeper, etc.
- **Dual UDP Broadcast** — Forward spots to two UDP destinations
- **Telegram + macOS Notifications** — Per-callsign cooldown, selectable alert levels
- **Sortable / resizable spots table** — click any column to sort, drag between headers to resize
- **Live filters** — Sources dropdown, Bands dropdown, New Only, Hide Duplicates (60s window)
- **Auto Start on Launch + Hide on Start** — runs as a menu-bar background service
- **Auto-clear with disk log** — prune old spots (0-120 min); pruned spots are appended to `DXC Spots.txt`
- **Universal binary** — native on both Apple Silicon and Intel Macs
- **Persistent settings** — all configuration saved automatically (backward-compatible Codable)

## Requirements

### System

| | |
|---|---|
| **Operating System** | macOS 14.0 (Sonoma) or later — Sonoma / Sequoia / Tahoe |
| **Architecture** | Apple Silicon (M1–M4) **or** Intel (shipped as a universal binary) |
| **RAM** | ~50–100 MB runtime |
| **Disk** | < 5 MB for the app; ~15 MB for ClubLog cache (log + cty.xml + matrix) |
| **Network** | Local LAN for WSJT-X/JTDX UDP; Internet for DX Cluster telnet + ClubLog API |

### Software (optional integrations)

The app runs standalone — all these are optional depending on which features you use:

- **WSJT-X** and/or **JTDX** — recent version with UDP broadcast enabled, pointing at the aggregator's listen port (default `2237`)
- **ClubLog account** with an **App Password** (Settings → App Passwords) and a **Developer API Key** ([request here](https://clublog.org/requestapikey.php)) — only needed for the alert/highlight features
- **Telegram bot** (via @BotFather) + your Chat ID — only if you want Telegram push alerts
- **Logging software** that connects to a telnet DX cluster (Logger32, N1MM+, Log4OM, DXKeeper, etc.) — point it at `127.0.0.1:7550` (or whatever port you configure)

### Build-from-source Requirements

Only needed if you're compiling the app yourself; end users don't need these.

- **Xcode Command Line Tools** — `xcode-select --install` (provides the Swift 5.9+ compiler)
- **macOS 15 SDK** — usually already installed alongside Xcode CLT. If you're on macOS 26 (Tahoe), you must pin the build to SDK 15 (`SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk`); otherwise the binary will refuse to launch on macOS 15 or earlier.
- **Python 3** with `Pillow` and `reportlab` — only required if you want to regenerate the app icon or PDF user manual (`generate_icon.py`, `generate_menubar_icon.py`, `generate_manual.py`).

## Installation

### Option 1: Download Pre-built App

1. Download `DXClusterAggregator.app` from [Releases](https://github.com/vu2cpl/DXClusterAggregator-macOS/releases)
2. Move it to your Applications folder (or anywhere you like)
3. **Important — First launch on macOS:**

   Since the app is not notarised through the Apple Developer Program, macOS will block it by default. To fix this, open Terminal and run:

   ```bash
   xattr -cr /path/to/DXClusterAggregator.app
   ```

   For example, if you placed it in Applications:
   ```bash
   xattr -cr /Applications/DXClusterAggregator.app
   ```

4. Right-click the app and select **"Open"** (not double-click) for the first launch
5. After the first launch, it will open normally with a double-click

### Option 2: Build from Source and Create .app Bundle

Requires Xcode Command Line Tools (`xcode-select --install`).

#### Step 1: Clone and Build

```bash
git clone https://github.com/vu2cpl/DXClusterAggregator-macOS.git
cd DXClusterAggregator-macOS
# Universal build (runs on both Apple Silicon and Intel Macs)
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk \
  swift build -c release --arch arm64 --arch x86_64
```

> **Notes:**
> - `--arch arm64 --arch x86_64` produces a universal binary that runs on both
>   Intel Macs and Apple Silicon.
> - On macOS 26 (Tahoe) you must pin the SDK to MacOSX15.sdk or earlier —
>   binaries built with the system-default SDK 26 will refuse to launch on
>   macOS 15 (Sequoia) and earlier.
> - The universal binary is placed in `.build/apple/Products/Release/` (not
>   `.build/release/`). Use that path when copying into the `.app`.

#### Step 2: Create the .app Bundle

```bash
# Create bundle directory structure
mkdir -p DXClusterAggregator.app/Contents/MacOS
mkdir -p DXClusterAggregator.app/Contents/Resources

# Copy the built binary (universal)
cp .build/apple/Products/Release/DXClusterAggregator DXClusterAggregator.app/Contents/MacOS/

# Copy the app icon
cp AppIcon.icns DXClusterAggregator.app/Contents/Resources/

# Copy the SwiftPM resource bundle (contains menu bar icon)
cp -R .build/apple/Products/Release/DXClusterAggregator_DXClusterAggregator.bundle \
      DXClusterAggregator.app/Contents/Resources/

# Create minimal Info.plist for the resource bundle so codesign accepts it
cat > DXClusterAggregator.app/Contents/Resources/DXClusterAggregator_DXClusterAggregator.bundle/Info.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.vu2cpl.dxclusteraggregator.resources</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
PLIST

# Create PkgInfo
echo -n "APPL????" > DXClusterAggregator.app/Contents/PkgInfo

# Create Info.plist
cat > DXClusterAggregator.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>DXClusterAggregator</string>
    <key>CFBundleDisplayName</key>
    <string>DX Cluster Aggregator</string>
    <key>CFBundleIdentifier</key>
    <string>com.vu2cpl.dxclusteraggregator</string>
    <key>CFBundleVersion</key>
    <string>1.2.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleExecutable</key>
    <string>DXClusterAggregator</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSLocalNetworkUsageDescription</key>
    <string>DX Cluster Aggregator needs network access to receive WSJT-X spots, connect to DX cluster nodes, and broadcast cluster data.</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
EOF
```

#### Step 3: Sign and Run

```bash
# Ad-hoc code sign
codesign --force --deep --sign - DXClusterAggregator.app

# Launch the app
open DXClusterAggregator.app
```

#### Optional: Install to Applications

```bash
cp -r DXClusterAggregator.app /Applications/
```

> **Note:** If sharing the built `.app` with others, they will need to run
> `xattr -cr /path/to/DXClusterAggregator.app` and right-click > Open on first launch
> (see Option 1 above).

## Quick Start

1. Launch the app
2. Set your **Callsign**
3. Configure UDP sources (default: WSJT-X on port 2237)
4. Optionally add DX Cluster nodes
5. Click **Start Monitoring**
6. Connect your logging software to **127.0.0.1:7550** (telnet)

## Default Configuration

| Setting | Default |
|---------|---------|
| Callsign | VU2CPL |
| WSJT-X UDP Port | 2237 |
| TCP Cluster Port | 7550 |
| Broadcast 1 | 127.0.0.1:2236 |

## Documentation

See the [User Manual (PDF)](DXClusterAggregator_UserManual.pdf) for detailed instructions.

## Credits

- **Original Windows Application:** Vinod, VU3ESV / LB9KJ
- **macOS Version Conceptualised by:** Manoj, VU2CPL
- **macOS Development:** Built with Claude Code (Anthropic)

## License

This project is shared for amateur radio use. 73!
