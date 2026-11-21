# NetQ

Native iOS (Swift 6, SwiftUI) network inspection tool: IP map, speed test, Wi-Fi / cellular / VPN checks, node latency.
Every number comes from a real network request or a system API. There is no simulated data.

## Build
Requires Xcode 26+, an iPhone running iOS 26+ (simulator works for most features), and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

    brew install xcodegen
    cd NetQ && xcodegen generate && open NetQ.xcodeproj

Select your signing team and run. No API keys are used or stored.

## Structure (`NetQ/NetQ/`)
App · Core (settings, HTTP, DNS C helper) · Network (path monitor, interfaces, cellular/Wi-Fi/VPN info) ·
SpeedTest (engine, models, report store, full-screen UI) · IPInfo · VPN (leak checks, IP history) ·
Node (store, TCP probe, UI) · Map · Detect · Settings · Components · Localization (zh-Hans / en, live switch)

## What each feature really does
- **Map**: MapKit. Device GPS (blue dot) and IP geolocation (orange pin) are shown separately.
- **Speed test**: Cloudflare public endpoints. HTTP-RTT ping, jitter, loss, 4-stream download/upload (8 s each, 1 s ramp-up discarded).
- **Nodes**: TCP-connect latency (20 attempts), loss, jitter, stability, HTTPS response time, geolocation. Download/upload only when you supply https test URLs for the node; otherwise N/A.
- **Wi-Fi / Cellular**: NWPathMonitor, CoreTelephony radio generation, interface addresses, system DNS servers.
- **VPN**: detects VPN-type interfaces via public system settings. It cannot see which VPN app or server is used (iOS forbids it). "Before VPN" IP comes only from a snapshot taken while no VPN was detected.
- **DNS leak / WebRTC**: DNS via bash.ws; WebRTC via a local page in the system WebView with a Google STUN server. Both verdicts are heuristics and say so. WebRTC scope is this app's WebView, not Safari.

## Known limits
- Wi-Fi name needs the *Access Wi-Fi Information* capability (paid developer account) + location permission; otherwise shown as unavailable.
- iOS no longer exposes the carrier name; "ISP" is from an IP database.
- iOS can't force cellular during a test; the report records the network actually used and warns on mismatch.
- A full speed test uses roughly 100–400 MB of data.
- Single built-in speed-test provider (Cloudflare). Nodes with your own https URLs act as alternatives.
- Online services have their own terms and rate limits (ipwho.is, ipapi.co free tiers especially). Check them before shipping.

## Privacy
No accounts, no NetQ servers, no analytics. Settings, nodes and reports stay on the device. Reports leave the device only when you share them.
Online services contacted: ipify, ipwho.is / ipapi.co, Cloudflare speed, bash.ws, Google STUN, and any node you add. They see your public IP.

## Third-party services and licenses
See `LICENSES.md` (also shown in-app: Settings → Open Source Licenses). No third-party source code is bundled; the glass UI uses Apple's native Liquid Glass APIs, so no LiquidGrass-style library is needed.
