# NetQ

NetQ 是一款 iOS 原生网络检测工具（Swift 6 + SwiftUI）：IP 地图、Cloudflare 测速、Wi-Fi / 蜂窝 / VPN 检查、节点 TCP 延迟，中英双语切换。所有数字都来自真实网络请求或系统 API，没有模拟数据。

## 下载

- 最新版：[v1.0.0](https://github.com/hmk849/netq/releases/download/v1.0.0/NetQ-unsigned.ipa)（未签名 IPA，约 360 KB）
- 系统要求：iOS 26.0 及以上，iPhone / iPad
- 签名：用 LCSign 普通证书自签即可，不需要 App Groups

## 功能

- **地图**：MapKit，设备 GPS（蓝点）与 IP 定位（橙色标记）分开展示。
- **测速**：Cloudflare 公共测速点，ping、抖动、丢包、四线程上下行（各 8 秒）。
- **节点**：TCP 连接延迟（20 次）、丢包、抖动、稳定性、HTTPS 响应时间、归属地。
- **Wi-Fi / 蜂窝**：网络路径、蜂窝制式、接口地址、系统 DNS 服务器。
- **VPN**：检测 VPN 类型接口；DNS 泄露与 WebRTC 泄露检查（均为启发式判断，结论会在 App 内注明）。
- **报告**：测速与节点报告保存在本机，可分享导出。

## 已知限制

- 包内没有 App 图标，装上是空白图标。
- Wi-Fi 名称需要付费开发者账号的 Access Wi-Fi Information 能力，否则显示不可用。
- iOS 不再提供运营商名称，“ISP”来自 IP 数据库。
- iOS 无法在测速时强制走蜂窝；报告会记录实际使用的网络，网络不符时会提示。
- 一次完整测速约用 100–400 MB 流量。

## 隐私

无账号、无自有服务器、无统计。设置、节点与报告只存在本机，报告只有你主动分享时才会离开设备。
联网的在线服务：ipify、ipwho.is / ipapi.co、Cloudflare 测速、bash.ws、Google STUN，以及你自己添加的节点。它们能看到你的公网 IP。

## 编译

需要 Xcode 26+ 与 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

    brew install xcodegen
    cd NetQ && xcodegen generate && open NetQ.xcodeproj

选自己的签名团队即可运行。不用任何 API key。

## 第三方服务与许可

见 `LICENSES.md`（App 内：设置 → 开源许可）。没有捆绑第三方源码；玻璃拟态界面用的是苹果原生 Liquid Glass API。

---

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
