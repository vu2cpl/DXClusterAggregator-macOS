# FT8ClusterAggregator for macOS

A native macOS application that aggregates FT8/FT4 spots from multiple WSJT-X/JTDX instances and DX Cluster nodes into a unified telnet cluster server.

## Features

- **Multiple UDP Sources** — Connect to several WSJT-X/JTDX instances simultaneously
- **DX Cluster Nodes** — Connect to telnet DX cluster servers with auto-authentication
- **Built-in Telnet Cluster Server** — Feed aggregated spots to Logger32, N1MM+, Log4OM, or any logging software
- **Dual UDP Broadcast** — Forward spots to two UDP destinations
- **CQ-Only Filter** — Filter to show only CQ calls
- **Persistent Settings** — All configuration saved automatically

## Installation

### Option 1: Download Pre-built App

1. Download `FT8ClusterAggregator.app` from [Releases](https://github.com/vu2cpl/FT8ClusterAggregator-macOS/releases)
2. Move it to your Applications folder (or anywhere you like)
3. **Important — First launch on macOS:**

   Since the app is not notarised through the Apple Developer Program, macOS will block it by default. To fix this, open Terminal and run:

   ```bash
   xattr -cr /path/to/FT8ClusterAggregator.app
   ```

   For example, if you placed it in Applications:
   ```bash
   xattr -cr /Applications/FT8ClusterAggregator.app
   ```

4. Right-click the app and select **"Open"** (not double-click) for the first launch
5. After the first launch, it will open normally with a double-click

### Option 2: Build from Source and Create .app Bundle

Requires Xcode Command Line Tools (`xcode-select --install`).

#### Step 1: Clone and Build

```bash
git clone https://github.com/vu2cpl/FT8ClusterAggregator-macOS.git
cd FT8ClusterAggregator-macOS
swift build -c release
```

#### Step 2: Create the .app Bundle

```bash
# Create bundle directory structure
mkdir -p FT8ClusterAggregator.app/Contents/MacOS
mkdir -p FT8ClusterAggregator.app/Contents/Resources

# Copy the built binary
cp .build/release/FT8ClusterAggregator FT8ClusterAggregator.app/Contents/MacOS/

# Copy the app icon
cp AppIcon.icns FT8ClusterAggregator.app/Contents/Resources/

# Create PkgInfo
echo -n "APPL????" > FT8ClusterAggregator.app/Contents/PkgInfo

# Create Info.plist
cat > FT8ClusterAggregator.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>FT8ClusterAggregator</string>
    <key>CFBundleDisplayName</key>
    <string>FT8 Cluster Aggregator</string>
    <key>CFBundleIdentifier</key>
    <string>com.vu2cpl.ft8clusteraggregator</string>
    <key>CFBundleVersion</key>
    <string>1.2.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleExecutable</key>
    <string>FT8ClusterAggregator</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSLocalNetworkUsageDescription</key>
    <string>FT8 Cluster Aggregator needs network access to receive WSJT-X spots, connect to DX cluster nodes, and broadcast cluster data.</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
</dict>
</plist>
EOF
```

#### Step 3: Sign and Run

```bash
# Ad-hoc code sign
codesign --force --deep --sign - FT8ClusterAggregator.app

# Launch the app
open FT8ClusterAggregator.app
```

#### Optional: Install to Applications

```bash
cp -r FT8ClusterAggregator.app /Applications/
```

> **Note:** If sharing the built `.app` with others, they will need to run
> `xattr -cr /path/to/FT8ClusterAggregator.app` and right-click > Open on first launch
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

## System Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac

## Documentation

See the [User Manual (PDF)](FT8ClusterAggregator_UserManual.pdf) for detailed instructions.

## Credits

- **Original Windows Application:** Vinod, VU3ESV / LB9KJ
- **macOS Version Conceptualised by:** Manoj, VU2CPL
- **macOS Development:** Built with Claude Code (Anthropic)

## License

This project is shared for amateur radio use. 73!
