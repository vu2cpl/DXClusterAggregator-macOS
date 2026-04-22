#!/usr/bin/env python3
"""Generate a professional PDF user manual for DXClusterAggregator."""

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm, cm
from reportlab.lib.colors import HexColor, black, white, grey
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle,
    KeepTogether, HRFlowable, ListFlowable, ListItem
)
from reportlab.pdfgen import canvas
from reportlab.lib import colors
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_PATH = os.path.join(BASE_DIR, "DXClusterAggregator_UserManual.pdf")

# Colors
NAVY = HexColor("#141E3C")
CYAN = HexColor("#00C8FF")
TEAL = HexColor("#00DCC8")
DARK_BLUE = HexColor("#1A2A5E")
LIGHT_BG = HexColor("#F0F4FA")
ACCENT = HexColor("#0088CC")

styles = getSampleStyleSheet()

# Custom styles
styles.add(ParagraphStyle(
    name='CoverTitle',
    parent=styles['Title'],
    fontSize=32,
    leading=38,
    textColor=NAVY,
    alignment=TA_CENTER,
    spaceAfter=8,
    fontName='Helvetica-Bold',
))

styles.add(ParagraphStyle(
    name='CoverSubtitle',
    parent=styles['Normal'],
    fontSize=16,
    leading=20,
    textColor=DARK_BLUE,
    alignment=TA_CENTER,
    spaceAfter=6,
    fontName='Helvetica',
))

styles.add(ParagraphStyle(
    name='CoverVersion',
    parent=styles['Normal'],
    fontSize=12,
    leading=16,
    textColor=grey,
    alignment=TA_CENTER,
    spaceAfter=4,
    fontName='Helvetica',
))

styles.add(ParagraphStyle(
    name='ChapterTitle',
    parent=styles['Heading1'],
    fontSize=22,
    leading=28,
    textColor=NAVY,
    spaceBefore=20,
    spaceAfter=12,
    fontName='Helvetica-Bold',
    borderWidth=0,
    borderColor=CYAN,
    borderPadding=0,
))

styles.add(ParagraphStyle(
    name='SectionTitle',
    parent=styles['Heading2'],
    fontSize=15,
    leading=20,
    textColor=DARK_BLUE,
    spaceBefore=14,
    spaceAfter=8,
    fontName='Helvetica-Bold',
))

styles.add(ParagraphStyle(
    name='SubSection',
    parent=styles['Heading3'],
    fontSize=12,
    leading=16,
    textColor=ACCENT,
    spaceBefore=10,
    spaceAfter=6,
    fontName='Helvetica-Bold',
))

styles.add(ParagraphStyle(
    name='Body',
    parent=styles['Normal'],
    fontSize=10,
    leading=14,
    textColor=black,
    alignment=TA_JUSTIFY,
    spaceAfter=6,
    fontName='Helvetica',
))

styles.add(ParagraphStyle(
    name='BodyBold',
    parent=styles['Normal'],
    fontSize=10,
    leading=14,
    textColor=black,
    spaceAfter=6,
    fontName='Helvetica-Bold',
))

styles.add(ParagraphStyle(
    name='BulletItem',
    parent=styles['Normal'],
    fontSize=10,
    leading=14,
    textColor=black,
    leftIndent=20,
    spaceAfter=3,
    fontName='Helvetica',
    bulletIndent=8,
))

styles.add(ParagraphStyle(
    name='CodeBlock',
    parent=styles['Normal'],
    fontSize=9,
    leading=12,
    textColor=HexColor("#333333"),
    backColor=LIGHT_BG,
    leftIndent=12,
    rightIndent=12,
    spaceBefore=4,
    spaceAfter=6,
    fontName='Courier',
))

styles.add(ParagraphStyle(
    name='Note',
    parent=styles['Normal'],
    fontSize=9,
    leading=13,
    textColor=DARK_BLUE,
    backColor=HexColor("#E8F0FE"),
    leftIndent=12,
    rightIndent=12,
    spaceBefore=6,
    spaceAfter=8,
    borderWidth=1,
    borderColor=ACCENT,
    borderPadding=8,
    fontName='Helvetica-Oblique',
))

styles.add(ParagraphStyle(
    name='Credits',
    parent=styles['Normal'],
    fontSize=10,
    leading=14,
    textColor=DARK_BLUE,
    alignment=TA_CENTER,
    spaceAfter=4,
    fontName='Helvetica',
))

styles.add(ParagraphStyle(
    name='Footer',
    parent=styles['Normal'],
    fontSize=8,
    leading=10,
    textColor=grey,
    alignment=TA_CENTER,
    fontName='Helvetica',
))

styles.add(ParagraphStyle(
    name='TOCEntry',
    parent=styles['Normal'],
    fontSize=11,
    leading=18,
    textColor=DARK_BLUE,
    leftIndent=10,
    fontName='Helvetica',
))

styles.add(ParagraphStyle(
    name='TOCSubEntry',
    parent=styles['Normal'],
    fontSize=10,
    leading=16,
    textColor=black,
    leftIndent=30,
    fontName='Helvetica',
))


def add_page_number(canvas_obj, doc):
    """Add page number and footer to each page."""
    canvas_obj.saveState()
    canvas_obj.setFont('Helvetica', 8)
    canvas_obj.setFillColor(grey)
    page_num = canvas_obj.getPageNumber()
    text = f"DXClusterAggregator User Manual  |  Page {page_num}"
    canvas_obj.drawCentredString(A4[0] / 2, 15 * mm, text)

    # Top accent line
    canvas_obj.setStrokeColor(CYAN)
    canvas_obj.setLineWidth(1.5)
    canvas_obj.line(20 * mm, A4[1] - 15 * mm, A4[0] - 20 * mm, A4[1] - 15 * mm)
    canvas_obj.restoreState()


def build_cover():
    """Build cover page elements."""
    elements = []
    elements.append(Spacer(1, 60 * mm))
    elements.append(Paragraph("DX Cluster Aggregator", styles['CoverTitle']))
    elements.append(Spacer(1, 4 * mm))
    elements.append(Paragraph("for macOS", styles['CoverSubtitle']))
    elements.append(Spacer(1, 8 * mm))
    elements.append(HRFlowable(width="40%", thickness=2, color=CYAN, spaceBefore=0, spaceAfter=0))
    elements.append(Spacer(1, 8 * mm))
    elements.append(Paragraph("User Manual", styles['CoverSubtitle']))
    elements.append(Spacer(1, 4 * mm))
    elements.append(Paragraph("Version 1.7.0", styles['CoverVersion']))
    elements.append(Spacer(1, 30 * mm))

    elements.append(Paragraph("Aggregate FT8/FT4 spots from multiple WSJT-X/JTDX instances", styles['Credits']))
    elements.append(Paragraph("and DX Cluster nodes into a unified telnet cluster server", styles['Credits']))
    elements.append(Spacer(1, 30 * mm))

    elements.append(HRFlowable(width="60%", thickness=1, color=grey, spaceBefore=0, spaceAfter=0))
    elements.append(Spacer(1, 6 * mm))
    elements.append(Paragraph("<b>Original Windows Application</b>", styles['Credits']))
    elements.append(Paragraph("Vinod VU3ESV / LB9KJ", styles['Credits']))
    elements.append(Spacer(1, 4 * mm))
    elements.append(Paragraph("<b>macOS Version Conceptualised by</b>", styles['Credits']))
    elements.append(Paragraph("Manoj VU2CPL", styles['Credits']))
    elements.append(Spacer(1, 4 * mm))
    elements.append(Paragraph("<b>macOS Version Developed with</b>", styles['Credits']))
    elements.append(Paragraph("Claude Code (Anthropic)", styles['Credits']))

    elements.append(PageBreak())
    return elements


def build_toc():
    """Build table of contents."""
    elements = []
    elements.append(Paragraph("Table of Contents", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    toc_items = [
        ("1.", "Introduction"),
        ("2.", "System Requirements"),
        ("3.", "Installation"),
        ("", "3.1  From Pre-built App Bundle"),
        ("", "3.2  Building from Source"),
        ("", "3.3  Creating the .app Bundle"),
        ("4.", "Getting Started"),
        ("", "4.1  Main Window Overview"),
        ("", "4.2  Setting Your Callsign"),
        ("5.", "Configuring UDP Sources (WSJT-X / JTDX)"),
        ("", "5.1  Adding a UDP Source"),
        ("", "5.2  Multiple Instances"),
        ("6.", "Configuring DX Cluster Sources"),
        ("", "6.1  Adding a DX Cluster Node"),
        ("", "6.2  Authentication"),
        ("7.", "Broadcast Destinations"),
        ("", "7.1  UDP Broadcast"),
        ("", "7.2  TCP Telnet Cluster Server"),
        ("8.", "Monitoring & Spot Aggregation"),
        ("", "8.1  Starting Monitoring"),
        ("", "8.2  CQ-Only Filter"),
        ("", "8.3  New-Only Filter"),
        ("", "8.4  Understanding the Spots Table"),
        ("9.", "ClubLog Integration & DX Alerts"),
        ("", "9.1  Required Credentials"),
        ("", "9.2  Configuration and Refresh"),
        ("", "9.3  Band Filter for Import"),
        ("", "9.4  Include Unconfirmed"),
        ("", "9.5  Alert Types and Highlighting"),
        ("10.", "Notifications (Telegram & macOS)"),
        ("", "10.1  Telegram Setup"),
        ("", "10.2  macOS Notifications"),
        ("", "10.3  Cooldown"),
        ("", "10.4  Notify-On Selection"),
        ("11.", "Connecting Logging Software"),
        ("12.", "Troubleshooting"),
        ("13.", "What's New in 1.7.0"),
        ("14.", "Credits & Acknowledgements"),
    ]

    for num, title in toc_items:
        if num:
            elements.append(Paragraph(f"<b>{num}</b>  {title}", styles['TOCEntry']))
        else:
            elements.append(Paragraph(title, styles['TOCSubEntry']))

    elements.append(PageBreak())
    return elements


def build_content():
    """Build all content pages."""
    elements = []

    # Chapter 1: Introduction
    elements.append(Paragraph("1. Introduction", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    elements.append(Paragraph(
        "DXClusterAggregator is a macOS application designed for amateur radio operators. "
        "It collects FT8, FT4, and other digital mode spots from multiple sources and aggregates "
        "them into a unified DX cluster feed that can be consumed by logging software such as "
        "Logger32, DXLab, N1MM+, Log4OM, and others.",
        styles['Body']
    ))

    elements.append(Paragraph(
        "The application supports two types of spot sources:",
        styles['Body']
    ))

    elements.append(Paragraph(
        "<bullet>&bull;</bullet> <b>UDP Sources</b> - Direct connections to WSJT-X, JTDX, or other software that broadcasts decoded FT8/FT4 spots via the WSJT-X UDP protocol",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> <b>DX Cluster Nodes</b> - Telnet connections to traditional DX cluster servers (DX Spider, AR-Cluster, CC Cluster, etc.) to receive spots from the worldwide cluster network",
        styles['BulletItem']
    ))

    elements.append(Paragraph(
        "All spots from all sources are combined and rebroadcast through a built-in telnet cluster "
        "server and/or UDP, allowing your logging software to receive a single aggregated stream "
        "of spots from multiple radios, SDRs, and cluster nodes.",
        styles['Body']
    ))

    elements.append(Paragraph(
        "This macOS version is a native Swift/SwiftUI port of the original Windows application "
        "created by Vinod VU3ESV/LB9KJ. The macOS version was conceptualised by Manoj VU2CPL.",
        styles['Body']
    ))

    # Chapter 2: System Requirements
    elements.append(Paragraph("2. System Requirements", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    req_data = [
        ['Requirement', 'Details'],
        ['Operating System', 'macOS 14.0 (Sonoma) or later'],
        ['Architecture', 'Apple Silicon (M1/M2/M3/M4) and Intel'],
        ['Disk Space', 'Less than 5 MB'],
        ['Network', 'Local network access for UDP/TCP'],
        ['Software', 'WSJT-X, JTDX, or compatible decoder (optional)'],
    ]

    req_table = Table(req_data, colWidths=[130, 330])
    req_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), NAVY),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('BACKGROUND', (0, 1), (-1, -1), LIGHT_BG),
        ('GRID', (0, 0), (-1, -1), 0.5, grey),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
    ]))
    elements.append(req_table)

    # Chapter 3: Installation
    elements.append(Paragraph("3. Installation", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    elements.append(Paragraph("3.1  From Pre-built App Bundle", styles['SectionTitle']))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Locate <b>DXClusterAggregator.app</b> in the distribution folder",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Drag it to your <b>/Applications</b> folder (or run from any location)",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> On first launch, macOS may show a security warning since the app is not notarised",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Go to <b>System Settings > Privacy & Security</b> and click <b>\"Open Anyway\"</b>",
        styles['BulletItem']
    ))

    elements.append(Paragraph(
        "Alternatively, open Terminal and run the following command to bypass Gatekeeper:",
        styles['Body']
    ))
    elements.append(Paragraph("xattr -cr /path/to/DXClusterAggregator.app", styles['CodeBlock']))
    elements.append(Paragraph(
        "Then right-click the app and select \"Open\" for the first launch. After that it will "
        "open normally with a double-click.",
        styles['Body']
    ))

    elements.append(Paragraph("3.2  Building from Source", styles['SectionTitle']))
    elements.append(Paragraph(
        "If you have the source code and Xcode Command Line Tools installed "
        "(install with: xcode-select --install):",
        styles['Body']
    ))
    elements.append(Paragraph("Step 1: Clone and build", styles['SubSection']))
    elements.append(Paragraph("git clone https://github.com/vu2cpl/DXClusterAggregator-macOS.git", styles['CodeBlock']))
    elements.append(Paragraph("cd DXClusterAggregator-macOS", styles['CodeBlock']))
    elements.append(Paragraph("swift build -c release", styles['CodeBlock']))

    elements.append(Paragraph("3.3  Creating the .app Bundle", styles['SectionTitle']))
    elements.append(Paragraph(
        "After building from source, you can create a proper macOS .app bundle that can be "
        "launched from Finder, placed in the Dock, or copied to /Applications:",
        styles['Body']
    ))

    elements.append(Paragraph("Step 1: Create the bundle directory structure", styles['SubSection']))
    elements.append(Paragraph("mkdir -p DXClusterAggregator.app/Contents/MacOS", styles['CodeBlock']))
    elements.append(Paragraph("mkdir -p DXClusterAggregator.app/Contents/Resources", styles['CodeBlock']))

    elements.append(Paragraph("Step 2: Copy the binary and icon", styles['SubSection']))
    elements.append(Paragraph("cp .build/release/DXClusterAggregator DXClusterAggregator.app/Contents/MacOS/", styles['CodeBlock']))
    elements.append(Paragraph("cp AppIcon.icns DXClusterAggregator.app/Contents/Resources/", styles['CodeBlock']))
    elements.append(Paragraph('echo -n "APPL????" > DXClusterAggregator.app/Contents/PkgInfo', styles['CodeBlock']))

    elements.append(Paragraph("Step 3: Create the Info.plist", styles['SubSection']))
    elements.append(Paragraph(
        "Create the file DXClusterAggregator.app/Contents/Info.plist with the following content "
        "(a template is provided in the project README):",
        styles['Body']
    ))

    plist_fields = [
        ['Key', 'Value'],
        ['CFBundleName', 'DXClusterAggregator'],
        ['CFBundleDisplayName', 'DX Cluster Aggregator'],
        ['CFBundleIdentifier', 'com.vu2cpl.dxclusteraggregator'],
        ['CFBundleVersion', '1.2.0'],
        ['CFBundleExecutable', 'DXClusterAggregator'],
        ['CFBundlePackageType', 'APPL'],
        ['CFBundleIconFile', 'AppIcon'],
        ['LSMinimumSystemVersion', '14.0'],
        ['NSHighResolutionCapable', 'true'],
    ]

    plist_table = Table(plist_fields, colWidths=[180, 280])
    plist_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), NAVY),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('BACKGROUND', (0, 1), (-1, -1), LIGHT_BG),
        ('GRID', (0, 0), (-1, -1), 0.5, grey),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('FONTNAME', (0, 1), (-1, -1), 'Courier'),
    ]))
    elements.append(plist_table)

    elements.append(Paragraph(
        "The full Info.plist XML template is available in the project README on GitHub.",
        styles['Note']
    ))

    elements.append(Paragraph("Step 4: Sign and launch", styles['SubSection']))
    elements.append(Paragraph("codesign --force --deep --sign - DXClusterAggregator.app", styles['CodeBlock']))
    elements.append(Paragraph("open DXClusterAggregator.app", styles['CodeBlock']))

    elements.append(Paragraph("Step 5 (Optional): Install to Applications", styles['SubSection']))
    elements.append(Paragraph("cp -r DXClusterAggregator.app /Applications/", styles['CodeBlock']))

    elements.append(Paragraph(
        "If sharing the built .app with others, they will need to run "
        "xattr -cr /path/to/DXClusterAggregator.app and right-click > Open on the first launch, "
        "as the app is not notarised through the Apple Developer Program.",
        styles['Note']
    ))

    # Chapter 4: Getting Started
    elements.append(PageBreak())
    elements.append(Paragraph("4. Getting Started", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    elements.append(Paragraph("4.1  Main Window Overview", styles['SectionTitle']))
    elements.append(Paragraph(
        "When you launch DXClusterAggregator, you will see the main window with the following sections from top to bottom. "
        "The <b>Hide Settings</b> button in the header collapses the entire configuration panel "
        "(Configuration, UDP Sources, DX Cluster, ClubLog) so the spots table can use the full window. "
        "Click <b>Show Settings</b> to bring the configuration back.",
        styles['Body']
    ))

    layout_data = [
        ['Section', 'Purpose'],
        ['Header', 'App name and version number'],
        ['Configuration', 'Callsign, TCP cluster port, and broadcast destinations'],
        ['UDP Sources', 'List of WSJT-X/JTDX UDP sources with IP, port, and status'],
        ['DX Cluster Nodes', 'List of telnet DX cluster sources with address, credentials, and status'],
        ['Controls', 'CQ-Only filter, Minimize on Start, Clear Spots, Start/Stop Monitoring'],
        ['Spots Table', 'Real-time display of aggregated spots from all sources'],
        ['Status Bar', 'Connection status, active source count, and total spot count'],
    ]

    layout_table = Table(layout_data, colWidths=[120, 340])
    layout_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), NAVY),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('BACKGROUND', (0, 1), (-1, -1), LIGHT_BG),
        ('GRID', (0, 0), (-1, -1), 0.5, grey),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    elements.append(layout_table)

    elements.append(Paragraph("4.2  Setting Your Callsign", styles['SectionTitle']))
    elements.append(Paragraph(
        "Enter your callsign in the <b>Callsign</b> field at the top of the window. This callsign "
        "is used as the spotter identifier when rebroadcasting spots through the cluster server. "
        "The callsign is automatically converted to uppercase. It is also used as the default "
        "username when adding new DX Cluster sources.",
        styles['Body']
    ))

    # Chapter 5: UDP Sources
    elements.append(Paragraph("5. Configuring UDP Sources (WSJT-X / JTDX)", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    elements.append(Paragraph(
        "UDP Sources receive decoded FT8/FT4/JT65/JT9 spots directly from WSJT-X, JTDX, or any "
        "software that implements the WSJT-X UDP protocol. The app parses the binary WSJT-X "
        "protocol messages (Status and Decode types) to extract spot information.",
        styles['Body']
    ))

    elements.append(Paragraph("5.1  Adding a UDP Source", styles['SectionTitle']))
    elements.append(Paragraph(
        "Click <b>\"Add UDP Source\"</b> in the UDP Sources section. Configure the following fields:",
        styles['Body']
    ))

    udp_fields = [
        ['Field', 'Description', 'Default'],
        ['Name', 'A label to identify this source (e.g., "WSJT-X 20m")', 'Source N'],
        ['Listen IP', 'IP to listen on. Use 0.0.0.0 for all interfaces', '0.0.0.0'],
        ['Port', 'UDP port number matching your WSJT-X/JTDX setting', '2237'],
        ['Enabled', 'Toggle to enable/disable this source', 'On'],
    ]

    udp_table = Table(udp_fields, colWidths=[70, 300, 80])
    udp_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), NAVY),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('BACKGROUND', (0, 1), (-1, -1), LIGHT_BG),
        ('GRID', (0, 0), (-1, -1), 0.5, grey),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    elements.append(udp_table)

    elements.append(Paragraph(
        "Note: In WSJT-X, go to File > Settings > Reporting and set the UDP Server address "
        "to 127.0.0.1 (or your Mac's IP if running on another machine) and the port to match "
        "the port configured here.",
        styles['Note']
    ))

    elements.append(Paragraph("5.2  Multiple Instances", styles['SectionTitle']))
    elements.append(Paragraph(
        "You can add multiple UDP sources to aggregate spots from several WSJT-X/JTDX instances "
        "running simultaneously. Each instance must be configured to broadcast on a different UDP "
        "port. For example:",
        styles['Body']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> WSJT-X on 20m band: UDP port 2237",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> JTDX on 40m band: UDP port 2238",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> WSJT-X on 15m band: UDP port 2239",
        styles['BulletItem']
    ))

    # Chapter 6: DX Cluster Sources
    elements.append(PageBreak())
    elements.append(Paragraph("6. Configuring DX Cluster Sources", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    elements.append(Paragraph(
        "DX Cluster sources connect to traditional DX cluster telnet servers to receive spots "
        "from the worldwide amateur radio spotting network. These spots are aggregated alongside "
        "your local WSJT-X/JTDX decodes.",
        styles['Body']
    ))

    elements.append(Paragraph("6.1  Adding a DX Cluster Node", styles['SectionTitle']))
    elements.append(Paragraph(
        "Click <b>\"Add DX Cluster\"</b> in the DX Cluster Nodes section. Configure the following fields:",
        styles['Body']
    ))

    dx_fields = [
        ['Field', 'Description', 'Default'],
        ['Name', 'A label for this cluster (e.g., "VE7CC")', 'Cluster N'],
        ['Address', 'Hostname or IP of the cluster node', '(empty)'],
        ['Port', 'Telnet port number', '7300'],
        ['Username', 'Your callsign for login', 'Your callsign'],
        ['Password', 'Password if required (many clusters do not require one)', '(empty)'],
        ['Enabled', 'Toggle to enable/disable', 'On'],
    ]

    dx_table = Table(dx_fields, colWidths=[70, 300, 80])
    dx_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), NAVY),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('BACKGROUND', (0, 1), (-1, -1), LIGHT_BG),
        ('GRID', (0, 0), (-1, -1), 0.5, grey),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    elements.append(dx_table)

    elements.append(Paragraph("Popular DX Cluster Nodes", styles['SubSection']))

    cluster_data = [
        ['Node', 'Address', 'Port'],
        ['VE7CC', 'dxc.ve7cc.net', '23'],
        ['W9PA', 'dxc.w9pa.net', '7300'],
        ['GB7DXC', 'gb7dxc.dxcluster.co.uk', '7300'],
        ['WA9PIE', 'dxc.wa9pie.net', '7300'],
        ['K1TTT', 'k1ttt.net', '7300'],
    ]

    cluster_table = Table(cluster_data, colWidths=[80, 230, 60])
    cluster_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), DARK_BLUE),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('BACKGROUND', (0, 1), (-1, -1), LIGHT_BG),
        ('GRID', (0, 0), (-1, -1), 0.5, grey),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
    ]))
    elements.append(cluster_table)

    elements.append(Paragraph("6.2  Authentication", styles['SectionTitle']))
    elements.append(Paragraph(
        "The application automatically detects login and password prompts from the cluster server. "
        "Most DX cluster nodes only require a callsign (no password). The app sends your username "
        "when it detects a login prompt, and your password (if provided) when it detects a password "
        "prompt. Connection status is shown next to each cluster entry:",
        styles['Body']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> <b>Connecting...</b> - TCP connection is being established",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> <b>Connected</b> - TCP connection established, waiting for login",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> <b>Authenticated</b> - Successfully logged in and receiving spots",
        styles['BulletItem']
    ))

    # Chapter 7: Broadcast Destinations
    elements.append(Paragraph("7. Broadcast Destinations", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    elements.append(Paragraph(
        "Aggregated spots are rebroadcast through two mechanisms:",
        styles['Body']
    ))

    elements.append(Paragraph("7.1  UDP Broadcast", styles['SectionTitle']))
    elements.append(Paragraph(
        "Two UDP broadcast destinations can be configured. Each has an IP address and port. "
        "Spots are sent as DX cluster-formatted text lines via UDP. Click <b>Save</b> after "
        "changing the settings. These can be used to feed spots to other applications on the "
        "local machine or across the network.",
        styles['Body']
    ))

    elements.append(Paragraph("7.2  TCP Telnet Cluster Server", styles['SectionTitle']))
    elements.append(Paragraph(
        "The app runs a built-in TCP telnet cluster server. Any logging software that supports "
        "connecting to a DX cluster via telnet can connect to this server to receive the aggregated "
        "spot feed. The default port is <b>7550</b>.",
        styles['Body']
    ))
    elements.append(Paragraph(
        "Configure your logging software to connect to:",
        styles['Body']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> <b>Host:</b> 127.0.0.1 (if on the same machine) or your Mac's IP address",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> <b>Port:</b> 7550 (or whatever you configured)",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "The status bar shows the number of connected telnet clients.",
        styles['Body']
    ))

    # Chapter 8: Monitoring
    elements.append(PageBreak())
    elements.append(Paragraph("8. Monitoring & Spot Aggregation", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    elements.append(Paragraph("8.1  Starting Monitoring", styles['SectionTitle']))
    elements.append(Paragraph(
        "Click the green <b>\"Start Monitoring\"</b> button to begin. This will:",
        styles['Body']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Start a UDP listener for each enabled UDP source",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Connect to each enabled DX Cluster node",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Start the TCP telnet cluster server",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Configure the UDP broadcast destinations",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "While monitoring is active, source settings cannot be modified. Click the red "
        "<b>\"Stop Monitoring\"</b> button to stop and reconfigure.",
        styles['Note']
    ))

    elements.append(Paragraph("8.2  CQ-Only Filter", styles['SectionTitle']))
    elements.append(Paragraph(
        "Enable the <b>CQ Only</b> toggle to filter spots so that only CQ calls are displayed "
        "and rebroadcast. This reduces the volume of spots to only stations calling CQ, which "
        "are the ones available to work. QSO exchanges (reports, RRR, 73) are filtered out.",
        styles['Body']
    ))

    elements.append(Paragraph("8.3  New-Only Filter", styles['SectionTitle']))
    elements.append(Paragraph(
        "Enable the <b>New Only</b> toggle to filter spots so that only those matching an "
        "enabled ClubLog alert are displayed and rebroadcast. A spot passes the filter if its "
        "classification is New DXCC, New Slot, New Band, or New Mode (whichever you have "
        "enabled in the ClubLog section). Worked stations and unclassified spots are hidden. "
        "This filter requires ClubLog data to be loaded via Refresh - without log data, every "
        "spot is unclassified and nothing will be shown.",
        styles['Body']
    ))
    elements.append(Paragraph(
        "Tip: combine <b>CQ Only</b> + <b>New Only</b> for the cleanest possible feed - only "
        "stations calling CQ that you actually need.",
        styles['Note']
    ))

    elements.append(Paragraph("8.4  Understanding the Spots Table", styles['SectionTitle']))
    elements.append(Paragraph(
        "The spots table displays all aggregated spots in real-time:",
        styles['Body']
    ))

    spots_fields = [
        ['Column', 'Description'],
        ['Time', 'UTC time of the spot (HHmm format)'],
        ['Source', 'Name of the source that provided this spot'],
        ['Callsign', 'The DX station callsign extracted from the message'],
        ['Freq (MHz)', 'Frequency in MHz (dial frequency + audio offset)'],
        ['SNR', 'Signal-to-noise ratio in dB (from WSJT-X decodes)'],
        ['Mode', 'Operating mode (FT8, FT4, CW, SSB, etc.)'],
        ['Message', 'Full decoded message or spot comment'],
    ]

    spots_table = Table(spots_fields, colWidths=[80, 380])
    spots_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), NAVY),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('BACKGROUND', (0, 1), (-1, -1), LIGHT_BG),
        ('GRID', (0, 0), (-1, -1), 0.5, grey),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    elements.append(spots_table)
    elements.append(Spacer(1, 4 * mm))
    elements.append(Paragraph(
        "CQ spots are highlighted with a green background in the table for easy identification.",
        styles['Note']
    ))

    # Chapter 9: ClubLog Integration
    elements.append(PageBreak())
    elements.append(Paragraph("9. ClubLog Integration & DX Alerts", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    elements.append(Paragraph(
        "The ClubLog integration (new in v1.3.0) downloads your personal log from ClubLog and "
        "classifies each incoming spot as new DXCC, new slot, new band, new mode, or already worked. "
        "Spots are color-highlighted in the spots table so you can instantly see which stations "
        "are worth working.",
        styles['Body']
    ))

    elements.append(Paragraph("9.1  Required Credentials", styles['SectionTitle']))
    elements.append(Paragraph(
        "You will need the following from your ClubLog account (free at https://clublog.org):",
        styles['Body']
    ))

    cred_fields = [
        ['Field', 'What it is', 'Where to get it'],
        ['Callsign', 'Your amateur radio callsign', 'Your ClubLog account callsign'],
        ['Email', 'Email address registered with ClubLog', 'Your ClubLog account email'],
        ['App Password', 'Token for API access (NOT your login password)', 'ClubLog > Settings > App Passwords'],
        ['API Key', 'Developer key for country file download', 'https://clublog.org/requestapikey.php'],
    ]

    cred_table = Table(cred_fields, colWidths=[80, 180, 200])
    cred_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), NAVY),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('BACKGROUND', (0, 1), (-1, -1), LIGHT_BG),
        ('GRID', (0, 0), (-1, -1), 0.5, grey),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    elements.append(cred_table)

    elements.append(Paragraph(
        "All credentials are stored locally on your Mac in UserDefaults. They are not transmitted "
        "anywhere except to ClubLog's own servers when you click Refresh.",
        styles['Note']
    ))

    elements.append(Paragraph("9.2  Configuration and Refresh", styles['SectionTitle']))
    elements.append(Paragraph(
        "In the ClubLog Integration section:",
        styles['Body']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Enter your <b>Callsign</b>, <b>Email</b>, <b>App Password</b>, and <b>API Key</b>",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Select which <b>Alert Types</b> you want highlighted (New DXCC, New Slot, New Band, New Mode)",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Click <b>Refresh from ClubLog</b> - this downloads the country file and your full ADIF log",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Wait for the status message to show the QSO and DXCC count (depending on log size, this may take 30-120 seconds)",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "The downloaded data is cached locally at "
        "~/Library/Application Support/DXClusterAggregator/ so the app loads instantly on next "
        "launch without re-downloading. You should refresh periodically (e.g. after each logging "
        "session) to keep the worked-status data up to date.",
        styles['Body']
    ))

    elements.append(Paragraph("9.3  Band Filter for Import", styles['SectionTitle']))
    elements.append(Paragraph(
        "The <b>Import Bands</b> grid in the ClubLog section lets you choose which bands' QSOs "
        "are imported from your ClubLog log. Useful if you only operate certain bands and want a "
        "smaller, faster matrix.",
        styles['Body']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> <b>All</b> button: import every band (default)",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> <b>HF Only</b> button: 160M through 10M",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Individual band checkboxes: pick exactly the bands you want",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "Changes take effect on the next Refresh (the import filter is applied during ADIF parsing).",
        styles['Note']
    ))

    elements.append(Paragraph("9.4  Include Unconfirmed", styles['SectionTitle']))
    elements.append(Paragraph(
        "Enable the <b>Inc. Unconfirmed</b> toggle to make worked-but-unconfirmed slots count as "
        "still needed. A slot is considered confirmed if any of LOTW_QSL_RCVD, QSL_RCVD, or "
        "EQSL_QSL_RCVD is set to Y in the ADIF record (also recognises ClubLog's matched flag). "
        "When this toggle is ON, the alert classifier compares against your confirmed slots only, "
        "so QSOs awaiting confirmation will trigger New DXCC / New Slot / etc. alerts. This is "
        "useful for award-chasers who want to re-work stations until confirmation is received.",
        styles['Body']
    ))

    elements.append(Paragraph("9.5  Alert Types and Highlighting", styles['SectionTitle']))

    alert_fields = [
        ['Indicator', 'Level', 'Meaning'],
        ['🔴 red row', 'New DXCC', 'You have never worked this DXCC entity'],
        ['🟠 orange row', 'New Slot', 'You have worked this DXCC but not on this exact band+mode combination'],
        ['🔵 blue row', 'New Band', 'You have worked this DXCC but not on this band (any mode)'],
        ['🟡 amber row', 'New Mode', 'You have worked this DXCC but not in this mode (any band)'],
        ['⚪ no highlight', 'Worked', 'You have already worked this station/slot - not needed'],
        ['(blank)', 'Unknown', 'Classification not possible (DXCC not resolved, or no log data loaded)'],
    ]

    elements.append(Paragraph(
        "A <b>slot</b> means a specific DXCC + Band + Mode combination. For example, if you "
        "have worked Japan on 20M FT8 and 40M CW, then a spot of a Japanese station on 15M FT8 "
        "is a <b>new slot</b> - Japan is worked (so not new DXCC), 15M is worked (for other "
        "entities), FT8 is worked, but this specific JA+15M+FT8 combination is not. Slots matter "
        "for awards like 5BDXCC, 9BDXCC, and triple-play.",
        styles['Body']
    ))

    alert_table = Table(alert_fields, colWidths=[110, 80, 270])
    alert_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), NAVY),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('BACKGROUND', (0, 1), (-1, -1), LIGHT_BG),
        ('GRID', (0, 0), (-1, -1), 0.5, grey),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    elements.append(alert_table)

    elements.append(Paragraph(
        "Priority order: New DXCC beats New Slot beats New Band beats New Mode beats Worked. "
        "If you disable a specific alert type via the toggle, spots at that level are displayed "
        "as Worked (no highlight).",
        styles['Body']
    ))

    elements.append(Paragraph(
        "The spots table now includes two extra columns: <b>DXCC</b> (the entity name, e.g. "
        "\"UNITED STATES\") and <b>Band</b> (e.g. \"20M\"). A small colored indicator appears at "
        "the far-left of each row showing the alert level at a glance.",
        styles['Body']
    ))

    elements.append(PageBreak())
    elements.append(PageBreak())
    elements.append(Paragraph("10. Notifications (Telegram & macOS)", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    elements.append(Paragraph(
        "DXClusterAggregator can push alerts to your Telegram chat and/or to the macOS "
        "Notification Center whenever a spot matching your selected alert types arrives. "
        "Alerts are throttled per callsign by a configurable cooldown to prevent spam.",
        styles['Body']
    ))

    elements.append(Paragraph("10.1  Telegram Setup", styles['SectionTitle']))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Create a Telegram bot via @BotFather and copy the <b>Bot Token</b>",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Send /start to your bot, then look up your <b>Chat ID</b> via @userinfobot or by visiting https://api.telegram.org/bot&lt;TOKEN&gt;/getUpdates",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> In DXClusterAggregator, open the <b>Notifications</b> section and enable <b>Telegram</b>",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Paste the Bot Token and Chat ID, then click <b>Send Test</b>",
        styles['BulletItem']
    ))

    elements.append(Paragraph("10.2  macOS Notifications", styles['SectionTitle']))
    elements.append(Paragraph(
        "Enable the <b>macOS Notifications</b> toggle. The first time you enable it, macOS will "
        "prompt you to allow notifications from DXClusterAggregator. Click <b>Allow</b>. Banners "
        "will then appear in the corner of your screen for each matching spot.",
        styles['Body']
    ))
    elements.append(Paragraph(
        "If you accidentally denied permission, open System Settings > Notifications, find "
        "DXClusterAggregator in the list, and re-enable Allow Notifications.",
        styles['Note']
    ))

    elements.append(Paragraph("10.3  Cooldown", styles['SectionTitle']))
    elements.append(Paragraph(
        "Set the <b>Cooldown</b> to a value between 5 and 60 minutes (default 15). Within this "
        "window, repeat spots of the same callsign do not trigger another notification. This "
        "prevents getting flooded by FT8 stations that decode every 15 seconds.",
        styles['Body']
    ))

    elements.append(Paragraph("10.4  Notify-On Selection", styles['SectionTitle']))
    elements.append(Paragraph(
        "Use the <b>Notify on</b> checkboxes to choose which alert levels should trigger a "
        "notification - independent of the table-highlight toggles in the ClubLog section. "
        "For example, you might highlight all four levels visually but only get notifications "
        "for new DXCC and new slot.",
        styles['Body']
    ))

    elements.append(PageBreak())
    elements.append(Paragraph("11. Connecting Logging Software", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    elements.append(Paragraph(
        "DXClusterAggregator acts as a telnet DX cluster server. To connect your logging software:",
        styles['Body']
    ))

    elements.append(Paragraph("Logger32", styles['SubSection']))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Go to Setup > Telnet > DX Cluster",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Set Host to <b>127.0.0.1</b> and Port to <b>7550</b>",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Click Connect",
        styles['BulletItem']
    ))

    elements.append(Paragraph("N1MM+", styles['SubSection']))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Go to Window > Telnet",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Enter <b>127.0.0.1:7550</b> as the cluster address",
        styles['BulletItem']
    ))

    elements.append(Paragraph("Log4OM", styles['SubSection']))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Go to Settings > Cluster",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> Add a new cluster with address <b>127.0.0.1</b> port <b>7550</b>",
        styles['BulletItem']
    ))

    elements.append(Paragraph("Any Telnet Client", styles['SubSection']))
    elements.append(Paragraph(
        "You can also test the cluster server using a terminal:",
        styles['Body']
    ))
    elements.append(Paragraph("telnet 127.0.0.1 7550", styles['CodeBlock']))

    # Chapter 11: Troubleshooting
    elements.append(PageBreak())
    elements.append(Paragraph("12. Troubleshooting", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    trouble_data = [
        ['Problem', 'Solution'],
        ['No spots appearing from WSJT-X',
         'Verify the UDP port in WSJT-X Settings > Reporting matches the port configured '
         'in DXClusterAggregator. Ensure WSJT-X is set to broadcast to 127.0.0.1 (or your '
         'Mac\'s IP). Check that the source is enabled and shows "Active" status.'],
        ['DX Cluster not connecting',
         'Verify the cluster address and port are correct. Check your internet connection. '
         'Some clusters may be down - try a different node. Check if a firewall is blocking '
         'outbound TCP connections.'],
        ['DX Cluster shows "Waiting..."',
         'The cluster node may be unreachable or the DNS lookup failed. Try using an IP '
         'address instead of a hostname.'],
        ['macOS security warning on launch',
         'Go to System Settings > Privacy & Security and click "Open Anyway". This is '
         'needed because the app is not notarised through the Apple Developer Program.'],
        ['Logging software cannot connect',
         'Ensure monitoring is started (green "Start Monitoring" button). Verify the TCP '
         'cluster port (default 7550) is not blocked by a firewall. Check that the port '
         'is not already in use by another application.'],
        ['Port already in use',
         'Another application is using the same port. Either close that application or '
         'change the port in DXClusterAggregator to an unused port number.'],
        ['Spots from cluster but no frequency',
         'DX Cluster spots include frequency information from the cluster server. '
         'This is normal - the frequency comes from the spotter, not from your radio.'],
    ]

    for i in range(1, len(trouble_data)):
        elements.append(Paragraph(f"<b>{trouble_data[i][0]}</b>", styles['BodyBold']))
        elements.append(Paragraph(trouble_data[i][1], styles['Body']))
        if i < len(trouble_data) - 1:
            elements.append(Spacer(1, 2 * mm))

    # Chapter 11: Credits
    elements.append(PageBreak())
    # Chapter 13: What's New in 1.7.0
    elements.append(PageBreak())
    elements.append(Paragraph("13. What's New in 1.7.0", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    elements.append(Paragraph("LoTW User Marker", styles['SectionTitle']))
    elements.append(Paragraph(
        "A new green dot appears after callsigns in the Callsign column for stations known "
        "to use ARRL Logbook of The World. The LoTW user list is downloaded from ARRL "
        "(default URL https://lotw.arrl.org/lotw-user-activity.csv) via the <b>Refresh "
        "LoTW users</b> button in the ClubLog section. The list is cached locally and reused "
        "across app launches. Toggle <b>Mark LoTW users</b> to show or hide the marker "
        "without losing the database.",
        styles['Body']
    ))

    elements.append(Paragraph("Beacon Detection", styles['SectionTitle']))
    elements.append(Paragraph(
        "Known beacons (all 18 NCDXF/IBP rotating beacons plus common national beacons) "
        "are labelled in the DXCC column with their location and network, and marked with "
        "a 🔔 icon at the left of the row instead of an alert colour. Callsigns carrying a "
        "<b>/B</b> or <b>/BCN</b> suffix are also treated as beacons even when not in the "
        "explicit database. Beacons never trigger alerts or notifications.",
        styles['Body']
    ))

    elements.append(Paragraph("Digital Modes Grouped as DATA", styles['SectionTitle']))
    elements.append(Paragraph(
        "FT8, FT4, RTTY, JT65, JT9, MSK144, PSK and every other digital mode now share one "
        "'DATA' slot for DXCC tracking purposes - matching how DXCC / LOTW / ClubLog awards "
        "count them. CW and voice modes (SSB / AM / FM / DIGITALVOICE etc.) remain separate. "
        "An FT4 spot no longer triggers a 'new mode' alert just because your log only has "
        "FT8 for that entity.",
        styles['Body']
    ))

    elements.append(Paragraph("Time-Bounded ClubLog Rules", styles['SectionTitle']))
    elements.append(Paragraph(
        "The ClubLog cty.xml contains historical prefix rules with &lt;start&gt; and &lt;end&gt; dates "
        "(e.g. the KARELO-FINN REPUBLIC prefix ended 1960-06-30). Those are now filtered by "
        "the current date, so modern Russian calls like RN1TV correctly resolve to EUROPEAN "
        "RUSSIA instead of the deleted entity.",
        styles['Body']
    ))

    elements.append(Paragraph("Auto Start on Launch", styles['SectionTitle']))
    elements.append(Paragraph(
        "New <b>Auto Start</b> toggle in the controls row. When enabled, monitoring kicks "
        "off automatically shortly after the app launches. Combined with <b>Hide on Start</b> "
        "this effectively runs the aggregator as a menu-bar background service from the "
        "moment you log in.",
        styles['Body']
    ))

    elements.append(Paragraph("DX Cluster Auto-Reconnect", styles['SectionTitle']))
    elements.append(Paragraph(
        "When a DX cluster connection drops (network blip, remote server restart, etc.) the "
        "client now retries automatically with capped exponential backoff: 10s, 30s, 60s, "
        "120s, then 5 minutes repeating. The Status column shows 'Reconnect in Xs (try N)' "
        "during the wait. A successful reconnect resets the counter. Clicking Stop Monitoring, "
        "disabling the source, or removing it stops the retry loop.",
        styles['Body']
    ))

    elements.append(Paragraph("Auto-Clear + Spot Log File", styles['SectionTitle']))
    elements.append(Paragraph(
        "The controls row has an <b>Auto Clear</b> field (0-120 minutes, default 60). A "
        "background timer prunes spots older than the cutoff. Before deletion the pruned "
        "spots are appended to ~/Library/Application Support/DXClusterAggregator/DXC Spots.txt "
        "(tab-separated with a header). The manual <b>Clear</b> button also writes to the same "
        "file. Setting auto-clear to 0 disables the prune.",
        styles['Body']
    ))

    elements.append(Paragraph("Hide Duplicates Filter", styles['SectionTitle']))
    elements.append(Paragraph(
        "New toggle next to CQ Only / New Only. When enabled, repeat spots of the same "
        "call / band / mode within a 60-second window are collapsed to a single row. Toggle "
        "off to see every decode.",
        styles['Body']
    ))

    elements.append(Paragraph("Sortable + Resizable Spots Table", styles['SectionTitle']))
    elements.append(Paragraph(
        "The spots list is now a native macOS Table: drag between column headers to resize "
        "any column, and click a header to sort by it (click again to toggle ascending/"
        "descending). Default order is Time, newest first.",
        styles['Body']
    ))

    elements.append(Paragraph("Band + Source Display Filters", styles['SectionTitle']))
    elements.append(Paragraph(
        "Two new dropdown menus in the controls row: <b>Sources</b> (pick which UDP and DX "
        "Cluster sources to display) and <b>Bands</b> (pick which bands to watch). Both are "
        "multi-select with All / preset / individual options. Independent from the ClubLog "
        "Import Bands setting - import all bands to the matrix, then narrow the live feed "
        "to whatever you're actively watching. Notifications also honour these filters.",
        styles['Body']
    ))

    elements.append(Paragraph("Universal Binary", styles['SectionTitle']))
    elements.append(Paragraph(
        "The shipped .app is now a universal binary (arm64 + x86_64), running natively on "
        "both Apple Silicon and Intel Macs.",
        styles['Body']
    ))

    elements.append(Paragraph("13.x Earlier Releases", styles['SubSection']))
    elements.append(Paragraph(
        "Versions 1.0-1.6 added the WSJT-X UDP listener, DX cluster telnet client, built-in "
        "telnet cluster server, dual UDP broadcast, ClubLog integration with alert classification, "
        "Telegram and macOS notifications with per-callsign cooldown, and the project rename "
        "from FT8ClusterAggregator to DXClusterAggregator.",
        styles['Body']
    ))

    # Chapter 14: Credits
    elements.append(PageBreak())
    elements.append(Paragraph("14. Credits & Acknowledgements", styles['ChapterTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=CYAN, spaceBefore=2, spaceAfter=10))

    elements.append(Spacer(1, 10 * mm))

    elements.append(Paragraph("<b>Original Windows Application</b>", styles['Credits']))
    elements.append(Spacer(1, 4 * mm))
    elements.append(Paragraph(
        "The original DXClusterAggregator was developed as a Windows .NET application by "
        "<b>Vinod, VU3ESV / LB9KJ</b>. His vision of aggregating FT8 spots from multiple "
        "sources into a unified DX cluster feed laid the foundation for this project.",
        styles['Body']
    ))

    elements.append(Spacer(1, 8 * mm))
    elements.append(HRFlowable(width="50%", thickness=0.5, color=grey, spaceBefore=0, spaceAfter=0))
    elements.append(Spacer(1, 8 * mm))

    elements.append(Paragraph("<b>macOS Version</b>", styles['Credits']))
    elements.append(Spacer(1, 4 * mm))
    elements.append(Paragraph(
        "The macOS version of DXClusterAggregator was conceptualised by "
        "<b>Manoj, VU2CPL</b>. This native Swift/SwiftUI port brings the functionality "
        "of the original Windows application to the Mac platform, with enhancements including "
        "multiple UDP source support, DX Cluster telnet node integration, and a modern macOS "
        "user interface.",
        styles['Body']
    ))

    elements.append(Spacer(1, 8 * mm))
    elements.append(HRFlowable(width="50%", thickness=0.5, color=grey, spaceBefore=0, spaceAfter=0))
    elements.append(Spacer(1, 8 * mm))

    elements.append(Paragraph("<b>Development</b>", styles['Credits']))
    elements.append(Spacer(1, 4 * mm))
    elements.append(Paragraph(
        "The macOS application was developed with the assistance of <b>Claude Code</b> by Anthropic, "
        "an AI-powered software engineering tool.",
        styles['Body']
    ))

    elements.append(Spacer(1, 8 * mm))
    elements.append(HRFlowable(width="50%", thickness=0.5, color=grey, spaceBefore=0, spaceAfter=0))
    elements.append(Spacer(1, 8 * mm))

    elements.append(Paragraph("<b>Open Source Libraries & Protocols</b>", styles['Credits']))
    elements.append(Spacer(1, 4 * mm))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> <b>WSJT-X UDP Protocol</b> - Joe Taylor K1JT and the WSJT-X development team",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> <b>DX Cluster Protocol</b> - DX Spider and AR-Cluster communities",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> <b>Apple Network Framework</b> - For TCP/UDP networking on macOS",
        styles['BulletItem']
    ))
    elements.append(Paragraph(
        "<bullet>&bull;</bullet> <b>SwiftUI</b> - Apple's modern UI framework for macOS",
        styles['BulletItem']
    ))

    elements.append(Spacer(1, 15 * mm))
    elements.append(HRFlowable(width="30%", thickness=1, color=CYAN, spaceBefore=0, spaceAfter=0))
    elements.append(Spacer(1, 6 * mm))
    elements.append(Paragraph("73 de VU2CPL", styles['Credits']))
    elements.append(Spacer(1, 4 * mm))
    elements.append(Paragraph("April 2026", styles['Footer']))

    return elements


def main():
    doc = SimpleDocTemplate(
        OUTPUT_PATH,
        pagesize=A4,
        leftMargin=20 * mm,
        rightMargin=20 * mm,
        topMargin=22 * mm,
        bottomMargin=20 * mm,
        title="DXClusterAggregator User Manual",
        author="Manoj VU2CPL",
        subject="User Manual for DXClusterAggregator macOS Application",
        creator="DXClusterAggregator",
    )

    elements = []
    elements.extend(build_cover())
    elements.extend(build_toc())
    elements.extend(build_content())

    doc.build(elements, onFirstPage=add_page_number, onLaterPages=add_page_number)
    print(f"User manual generated: {OUTPUT_PATH}")
    print(f"File size: {os.path.getsize(OUTPUT_PATH) / 1024:.1f} KB")


if __name__ == "__main__":
    main()
