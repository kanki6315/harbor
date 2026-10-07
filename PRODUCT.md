# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

Swift, SwiftUI, WKWebView/WebKit, Apple-native persistence and frameworks. No third-party dependencies without a major benefit.

## Users

Personal iPhone browser for general browsing instead of Chrome. The user expects sessions to grow beyond 40 tabs and anticipates tab groups later.

## Product Purpose

Reduce tracking while preserving everyday browsing, website logins, local storage, and open tabs across app launches.

## Capabilities and Constraints

Persistent normal browsing; combined address/search entry; DuckDuckGo by default with Google and Bing choices; navigation, sharing, tab creation/closing/switching/restoration; bundled WebKit tracker rules; tracking parameter cleaning; persistent per-site blocking exceptions; local history and bookmarks; settings and explicit browsing-data deletion. Basic downloads if practical.

Use the normal persistent WebKit data store. No app analytics, telemetry, ad SDKs, or crash reporting SDKs. Preserve TLS validation and standard user agent. Never fabricate blocked-request counts. Document platform limitations during implementation.

First usable milestone: browse, sign in, open tabs, relaunch with tabs and website sessions retained where the website allows, block common trackers, and disable blocking for a broken site.

Tab groups are a future feature to accommodate in the design, not a confirmed MVP implementation requirement. Other future features include profiles, optional private sync, Face ID, reader mode, custom lists, and iPad layout.

## Brand Commitments

Minimal, fast, native, unobtrusively privacy-focused. Safari, DuckDuckGo, and Firefox Focus are references without copying their branding. SF Symbols, light and dark mode, Dynamic Type.

User supplied the Harbor brand identity and requested iOS Liquid Glass patterns. Brand reference: `design/brand/harbor-identity.png`. Harbor Navy #0D2747, Harbor Blue #2F8CE6, Wave #7CC3F3, Mist #E8F0F8, Sun #FFDFA6, Slate #1E293B. Preserve the arch, sun and water-reflection mark. Inter is the supplied brand typeface; native system control typography remains appropriate. Glass belongs in native navigation and control layers, with accessible material fallbacks. The user found the first Index/Cove/Slate concepts too similar; the next round must vary the experience and composition substantially within this identity.

## Evidence on Hand

Selected design direction: Horizon's Harbor-branded start page with Collections' approach to future tab organization. See `DESIGN.md` and `design/BROWSER-SURFACE.md`. Selection does not expand tab groups into MVP scope. The current task is documentation only, before app implementation.

Detailed user-supplied browser brief and Harbor identity board. Empty repository at discovery; no incumbent implemented interface. Harbor is the supplied brand name.

Existing logo sources: `assets/HarborIcon/Harbor.icon/`, separate SVG layers, and default/dark previews. Preserve these assets as the production logo source.

## Product Principles

- Preserve browsing continuity.
- Keep privacy truthful and easy to adjust per site.
- Make large tab sessions navigable.
- Prefer a small, maintainable native implementation.

## Accessibility & Inclusion

Dynamic Type and light/dark appearances required. Preserve native navigation, readable labels, and accessible controls.
