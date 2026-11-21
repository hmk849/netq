# Third-party services and frameworks used by NetQ

No third-party source code is bundled. NetQ calls the online services below and uses Apple system frameworks.
Licenses/terms for online services are the providers' own; verify current terms and limits before distribution.

| Name | Author | URL | License / terms | Purpose |
|---|---|---|---|---|
| ipify | ipify | https://www.ipify.org | Public API, site terms | Public IPv4/IPv6 |
| ipwho.is | ipwho.is | https://ipwho.is | Public API, site terms | IP geolocation (primary) |
| ipapi.co | ipapi.co | https://ipapi.co | Public API, free-tier limits | IP geolocation (fallback) |
| Cloudflare speed endpoints | Cloudflare, Inc. | https://speed.cloudflare.com | Public endpoints, terms apply | Ping, download, upload tests |
| bash.ws DNS leak test | bash.ws | https://bash.ws | Public API, site terms | DNS leak test |
| Google public STUN server | Google LLC | https://developers.google.com/speed/public-dns | Public service, terms apply | WebRTC exposure probe |
| MapKit, CoreLocation, Network, CoreTelephony, NetworkExtension, WebKit, SwiftUI | Apple Inc. | https://developer.apple.com/documentation | Apple SDK license | Maps, location, path monitoring, radio type, Wi-Fi info, probe page, UI |

Developer: hmk849 (https://github.com/hmk849, https://github.com/hmk11131, https://x.com/hmk2778)
