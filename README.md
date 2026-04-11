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

### Option 2: Build from Source

Requires Xcode Command Line Tools.

```bash
git clone https://github.com/vu2cpl/FT8ClusterAggregator-macOS.git
cd FT8ClusterAggregator-macOS
swift build -c release
open .build/release/FT8ClusterAggregator
```

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
