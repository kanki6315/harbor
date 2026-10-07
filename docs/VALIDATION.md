# Validation — 2026-10-07

Environment: Xcode 27.0 (27A266a), iOS 27 SDK, iPhone 18 Pro simulator running iOS 27.0. No physical-device or signing credentials were used.

## Build results

- Debug iPhone Simulator build: **passed**.
- Unsigned Release build for generic iOS/arm64: **passed**.
- Supplied `Harbor.icon` compiled by Xcode’s asset tooling.
- Bundle identifier: `com.arjunakankipati.harbor`.
- No application compiler warnings in the final Release build. Xcode reports that App Intents metadata extraction is skipped because the app does not use App Intents.

## Automated results

The full run completed with **12 tests passed, 1 compatibility test skipped, 0 failures**.

| Check | Result |
| --- | --- |
| Domain/search input and search-engine routing | Passed |
| Exact parameter preservation; signed/media URL exclusions | Passed |
| Atomic archive round trip, selection and site exceptions | Passed |
| Persistent WebKit cookies shared between independently created views | Passed |
| Restore-off behavior preserves bookmarks/settings | Passed |
| Bundled tracker JSON compiles with WebKit | Passed |
| Media configuration: inline, PiP, AirPlay, user gesture | Passed |
| 41-tab metadata restoration, close and undo; lazy view creation | Passed |
| Start page → tabs → new tab → termination/relaunch → settings | Passed |
| Synthetic HTML5 video play/pause across switcher and actual tab switch, without recreating the page | Passed |
| Synthetic HTML5 audio and native full-screen video entry/exit | Passed |
| User-clicked popup opens a separate tab, loads HTTPS, then restores that page after relaunch | Passed |
| Apple HLS sample starts via user interaction with rules installed | Passed |
| Direct YouTube embed playback | **Skipped after observed provider Error 153** |

Some rows cover several assertions inside one test. Passing the cookie-store test does not claim a particular website account remains authenticated forever.

Full result bundle during this build: `/tmp/harbor-build/Logs/Test/Test-Harbor-2026.10.07_00-15-06--0400.xcresult`. Xcode result bundles and simulator captures are local build evidence, not production resources.

## YouTube observation

The direct URL `https://www.youtube.com/embed/9zjeImiYtow` loaded YouTube’s player shell, then displayed **“Video player configuration error” / “Error 153”**. No play control was available. The compatibility test records a screenshot and skips; it does not count this as successful video playback.

YouTube documents Error 153 as missing HTTP Referer or equivalent client identification in its [iframe player API reference](https://developers.google.com/youtube/iframe_api_reference#onError). Navigating directly to an embed URL has no embedding page, which is consistent with this response. This is not proof that ordinary YouTube watch pages or embeds on real websites fail. Those remain separate physical-device checks. Harbor does not spoof a referrer, change its user agent, disable TLS validation, or bypass the provider restriction.

## Manual checks still required

- Real account sign-in and persistent login after force-quit/relaunch.
- YouTube watch pages and embeds on actual HTTPS pages; Vimeo and Twitch playback.
- Real AirPlay receiver and Picture in Picture entry/restore on supported sites.
- Repeated full-screen transitions with device rotation.
- Lock/unlock and background/foreground behavior on a physical iPhone.
- Media compatibility with blocking on versus per-site exceptions.
- Download/share-to-Files on real websites, including authenticated attachments.
- VoiceOver navigation, Increase Contrast and Reduce Transparency on hardware.
- Sustained memory pressure with multiple media tabs and 40+ ordinary pages.

These are deliberately unverified. API configuration and simulator checks cannot establish all device/site combinations. The complete step-by-step checklist is in the README.

## Final chrome and design verification

The contrast reviewer confirmed the address prompt and first-run supporting copy corrections resolved in light, dark and largest-text captures. This is a scoped review, not certification of every screen or hardware setting.

After the user requested transparent chrome and a centered tab count, two focused UI tests passed (video across tab switching and native audio/fullscreen), including assertions that the website frame extends behind both the status area and bottom controls. A third focused test passed start-page navigation, tabs, restoration and settings after the start-page extension. Native screenshots confirm content beneath the glass capsules and the centered count; the reviewer accepted these requested changes with no material visual issue. Reduce Transparency intentionally retains the accessible opaque capsule fallback.

Final focused result bundles: `Test-Harbor-2026.10.07_00-26-58--0400.xcresult` and `Test-Harbor-2026.10.07_00-28-13--0400.xcresult`, under `/tmp/harbor-build/Logs/Test/`.
