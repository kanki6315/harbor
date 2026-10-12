# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

Swift, SwiftUI, WKWebView/WebKit, Apple-native persistence and frameworks. No third-party dependencies without a major benefit.

## Users

Personal iPhone browser for general browsing instead of Chrome. The user expects sessions to grow beyond 40 tabs and uses optional named tab groups to organize them.

## Product Purpose

Reduce tracking while preserving everyday browsing, website logins, local storage, and open tabs across app launches.

## Capabilities and Constraints

Persistent normal browsing; combined address/search entry; DuckDuckGo by default with Google and Bing choices; navigation, sharing, tab creation/closing/switching/restoration; bundled WebKit tracker rules; tracking parameter cleaning; persistent per-site blocking exceptions; local history and bookmarks; settings and explicit browsing-data deletion. Basic WebKit downloads with system sharing are implemented.

Use a separate persistent WebKit data store per profile, retaining the legacy default store only for a migrated original profile. No app analytics, telemetry, ad SDKs, or crash reporting SDKs. Preserve TLS validation and standard user agent. Never fabricate blocked-request counts. Platform and verification limits are recorded in `docs/VALIDATION.md`.

First usable milestone: browse, sign in, open tabs, relaunch with tabs and website sessions retained where the website allows, block common trackers, and disable blocking for a broken site.

Named tab groups are implemented within each profile: create, rename, move tabs, remove membership, and delete a group while keeping its tabs open. All Tabs represents each group as one card alongside ungrouped tabs; opening a group shows its individual tabs. Search follows the selected scope and finds group cards by name or matching members. Groups, membership and the selected scope persist with the local tab session. Profiles include isolated browsing data and an optional inactivity-based return to a default profile. Other future features include optional private sync, Face ID, reader mode, custom lists, and iPad layout.

## Brand Commitments

Minimal, fast, native, unobtrusively privacy-focused. Safari, DuckDuckGo, and Firefox Focus are references without copying their branding. SF Symbols, light and dark mode, Dynamic Type.

User supplied the Harbor brand identity and requested iOS Liquid Glass patterns. Brand reference: `design/brand/harbor-identity.png`. Harbor Navy #0D2747, Harbor Blue #2F8CE6, Wave #7CC3F3, Mist #E8F0F8, Sun #FFDFA6, Slate #1E293B. Preserve the arch, sun and water-reflection mark. Inter is the supplied brand typeface; native system control typography remains appropriate. Glass belongs in native navigation and control layers, with accessible material fallbacks.

## Evidence on Hand

Selected design direction: Horizon's Harbor-branded start page with Collections as the organization reference. The user subsequently approved named, profile-specific tab groups with All Tabs, tab movement and persistence. See `DESIGN.md` for the preserved visual system and `design/BROWSER-SURFACE.md` for current behavior. The native SwiftUI/WebKit implementation now follows this identity, with a still Canvas Horizon, bundled InterVariable branding and native functional typography.

Detailed user-supplied browser brief and Harbor identity board. The implemented app lives in `Harbor/`, with bundle identifier `com.arjunakankipati.harbor`. First run contains no fabricated history or favorites; later content comes from local browsing and bookmarks.

Existing logo sources: `assets/HarborIcon/Harbor.icon/`, separate SVG layers, and default/dark previews. Preserve these assets as the production logo source. Xcode references the supplied `.icon` directly.

Validation: 12 automated tests passed and one direct YouTube embed compatibility test skipped after observed provider Error 153. Unsigned device Release build passed. These results do not establish physical-device, every-site or global visual approval; see `docs/VALIDATION.md` for evidence and remaining checks.

## Product Principles

- Preserve browsing continuity.
- Keep privacy truthful and easy to adjust per site.
- Make large tab sessions navigable.
- Prefer a small, maintainable native implementation.

## Accessibility & Inclusion

Dynamic Type and light/dark appearances required. Preserve native navigation, readable labels, and accessible controls.
