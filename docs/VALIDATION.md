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

## Release recovery verification

The release attempt on the iPhone 17 simulator failed before test execution while launching the app and UI test runner. The terminal was force-closed, leaving its result bundle incomplete. Local `.release.env` now selects the previously working iPhone 18 Pro by UDID.

A fresh full run exposed covered web controls in the HLS and popup tests after the transparent-chrome change. The browser now measures chrome height and applies explicit WebKit scroll insets; tests scroll targets above the native controls and assert their reachability before tapping. The subsequent full run passed 12 tests with the existing YouTube compatibility skip and no failures. Website geometry still extends beneath the status area and glass bars. No archive or upload was performed during this recovery.

## Collapsible controls verification — October 7, 2026

The bottom bars now collapse explicitly into a bottom-right 56 × 44pt restore handle. Both states reserve their own space outside the website viewport. This supersedes the earlier transparent-overlay geometry and manual WebKit scroll-inset workaround described above; fixed-position site footers stay inside the visible page. Start-page scrolling is clipped above the controls.

On iPhone 17 Pro / iOS 26.5 Simulator, four targeted UI tests passed: collapse/restore with a tappable fixed footer and end-of-page action; largest-text/landscape geometry and editing; live video across tab switching; and audio/native fullscreen return. After capping the restore symbol to match the other toolbar icons, the large-text/landscape test passed again with actual simulator dark appearance. Rotation assertions now wait for settled geometry; full-screen screenshots avoid the app-capture rotation artifact. Result bundles: `/tmp/harbor-chrome-review/verified.xcresult` and `/tmp/harbor-chrome-review/final-appearance.xcresult`. Captures are in `.impeccable/review/phone-*.png` locally.

This is targeted simulator validation, not a new full-suite or physical-device signoff.

## Floating URL pill revision — October 7, 2026

The user's Safari references supersede the reserved-strip approach above. Browser controls again float over page content with no solid bottom surround. Scrolling down a website minimizes the two rows into a centered URL pill; tapping it restores both rows without focusing the address field. Switching tabs restores expanded controls. The viewport height stays unchanged during collapse; measured bottom scroll insets keep ordinary page-end content reachable. This does not guarantee clearance for every CSS fixed footer.

Three targeted UI tests passed on iPhone 17 Pro / iOS 26.5 Simulator: scroll-collapse/URL restoration and end-page action; accessibility text/landscape/editing; video across tab switching. The appearance test also passed in simulator dark mode. Evidence: `/tmp/harbor-chrome-review/floating.xcresult` and `/tmp/harbor-chrome-review/floating-dark.xcresult`; current captures in `.impeccable/review/`. Physical-device and arbitrary-site verification remain outstanding.

## Browser control motion — October 7, 2026

Expanded and minimized address glass now share a native glass identity inside a GlassEffectContainer. Collapse uses a 240ms smooth transition; restore uses 320ms, both without bounce. The action row fades with a 12pt offset. Reduce Motion selects a 120ms opacity transition without shared-glass morphing or action-row displacement.

Simulator tests passed for scroll-collapse/restoration and page-end access, accessibility text/landscape/editing, and three consecutive collapse/restore cycles with usable tabs and no unintended keyboard. Results: `/tmp/harbor-chrome-review/motion.xcresult` and `motion-repeat.xcresult`; transition recording: `/tmp/harbor-chrome-review/motion.mp4`. Reduce Motion behavior was reviewed in code; device-level accessibility and performance remain unverified.

## Isolated profiles and inactivity return — October 7, 2026

Profiles use separate browser archives and named persistent WebKit stores. A migrated original profile retains the default WebKit store, preserving its existing website sessions. Profile selection, default profile, timeout and background timestamp are stored atomically in a separate registry.

Core/WebKit coverage now includes archive and settings separation; migration without re-import; corrupt metadata preservation; switching away from an unreadable archive; cookie sharing within a profile and isolation between profiles; local storage, IndexedDB and session storage separation; scoped clearing; popup ownership and disposed-session callbacks; a real loopback HTTP download completing in its originating profile after a switch; profile deletion, default fallback and retained-web-view deletion retry; and timeout boundaries, Never, backward clock changes, repeated background notifications and relaunch selection.

The real one-minute UI test passed on iPhone 17 Pro / iOS 26.5 Simulator. It configured the timer through the app, verified a short background return and a short terminate/relaunch both retain Work, then verified a return after 61 seconds opens Personal. Evidence: `/tmp/harbor-profiles-ios26/Logs/Test/Test-Harbor-2026.10.07_15-38-07--0400.xcresult`. Cold-launch expiration is independently covered with injected dates in the manager tests; no real-time cold-launch expiration wait was run.

The final iOS 26.5 core run passed 18 tests, including the bounded deletion retry, plus the profile accessibility UI test in actual simulator dark appearance. Evidence: `/tmp/harbor-profiles-ios26/Logs/Test/Test-Harbor-2026.10.07_15-41-56--0400.xcresult`. Light and largest-text dark captures are exported to `.impeccable/review/phone-profile*.png`. The first large-text inspection prompted a stacked edit action so the current profile name remains readable.

Existing UI checks for video across tab switching, popup/public navigation and session restoration/settings passed on iPhone 18 Pro / iOS 27 Simulator. Their combined run also exposed the deletion-retry issue described above, which was fixed and passed in the later core run; this is not a claim that the earlier combined result bundle was green. Release device compilation (unsigned) passed after the final runtime changes. These are targeted simulator/build checks; physical-device sign-in, media-provider behavior and hardware accessibility checks listed above remain separate.

Final iOS 27 verification passed all 18 core/WebKit tests and the profile-management and live-page active-profile deletion UI tests in `/tmp/harbor-profiles-build/Logs/Test/Test-Harbor-2026.10.07_15-42-40--0400.xcresult`. That run's timeout-editor test used an incorrect standalone-static-text query for a grouped SwiftUI accessibility value. After changing assertions to reopen the editor and verify persisted values, its focused rerun passed: `/tmp/harbor-profiles-build/Logs/Test/Test-Harbor-2026.10.07_15-45-10--0400.xcresult`. It verifies zero is rejected, a custom five-minute duration is saved and restored, and Never is saved and restored. The combined earlier bundle remains a failed bundle; the corrected focused rerun is the passing evidence for that test.

The independent native finish review returned **ship** for the five supplied profile captures and relevant source, with no material fixes. Scope: standard light iPhone 18 Pro/iOS 27, largest accessibility text in dark mode iPhone 17 Pro/iOS 26.5, profile management/creation and the return settings editor. Dark lower return settings, physical hardware, full VoiceOver traversal and motion quality were not visually certified. The documentation check confirmed the extension preserves incumbent native component conventions and design tokens; pre-existing design-sidecar drift was not repaired.

## Storage and backup policy — October 7, 2026

All 22 HarborTests passed on iPhone 17 Pro / iOS 26.5 Simulator after splitting backup-eligible preferences from excluded browsing sessions. New coverage verifies legacy archive migration, interrupted second-write recovery, exclusion resource values, restoration without session/background files, and migration of inactive profiles and legacy background timestamps. Existing profile isolation, inactivity return, WebKit and download tests also passed. Result: `/tmp/harbor-backup-policy/Logs/Test/Test-Harbor-2026.10.07_16-59-39--0400.xcresult`.

Backup restoration was simulated by removing the excluded directories; no actual iCloud backup/restore or physical-device validation was performed. WebKit-owned storage remains unchanged. Old backups are not modified. Preferences and session files are individually atomic, not a cross-file transaction.

## Tab ordering and saved previews — 2026-10-07

- Simulator build passed. Six CoreTests passed, covering ordering/selection/archive persistence, preview round-trip and profile isolation, pruning, and releasing a background session while retaining its record/preview and removing that preview during data clearing.
- The targeted `testTabReorderAndUnloadedPreview` UI flow passed on iPhone 18 Pro / iOS 27 in standard light appearance and dark appearance with accessibility-extra-large text. It pauses fixture media, unloads a background tab, drags the native reorder handle, verifies the resulting first row, relaunches and checks the unloaded state. Captures show the stored page preview surviving relaunch.
- Final screenshots: `.impeccable/review/phone-tabs-restored.png`, `phone-tabs-reorder.png`, `phone-tabs-dark-large.png`, and `phone-tabs-reorder-dark-large.png`. Fixture content is local test data, not production seed content.
- Initial UI attempts exposed test selector ambiguity and an iOS 26.5 simulator interruption. Corrected selectors and explicit media pause passed on iOS 27. No full-suite, physical-device, VoiceOver gesture, long-session performance or grid drag autoscroll verification is claimed.
- Previews are the last successful local capture, not offline pages or saved form/navigation state. Unloaded pages reload on selection; pages without a successful capture retain the placeholder.
- Independent Impeccable finish review: **ship** for this tab refinement, based on the four final phone captures, incumbent design and relevant source. No material fixes requested; this is a scoped simulator review.

### 0.1.5 integration verification

After integrating main's Face ID profile locks and saved tab previews, all 29 HarborTests passed on iPhone 17 Pro / iOS 26.5 Simulator. Version 0.1.5 is set in both project.yml and the Xcode project. Result: `/tmp/harbor-backup-policy/Logs/Test/Test-Harbor-2026.10.07_17-01-47--0400.xcresult`. This was a simulator test build, not an archive or TestFlight upload.

## Floating browser destinations — October 7, 2026

Refreshed DESIGN.md and its Impeccable sidecar before implementing dedicated History/Settings at the top right, Bookmarks at the bottom right, and contextual Page actions at the top left. Profile management remains in Settings and the address-row profile shortcut stays available. The final top controls overlay content with no reserved row or full-width background; scrolling and address editing hide them.

Simulator build passed on iPhone 18 Pro / iOS 27. Four initial targeted UI tests passed for destinations/bookmark add-remove, accessibility-size controls, collapse/restore, and tab restoration/settings. A focused rerun after local bookmark labels were shortened passed in actual simulator dark appearance (the launch argument alone did not apply dark appearance). After the user's overlay correction, both destination/bookmark and collapse/restore tests passed again, including assertions that website content extends behind the top buttons and retains the same frame when controls collapse. Final result: `/tmp/harbor-controls-build/Logs/Test/Test-Harbor-2026.10.07_17-36-04--0400.xcresult`.

Inspected final light website controls and dark largest-text start-page controls. Captures: `/tmp/harbor-overlay-captures/controls-light.png` and `/tmp/harbor-overlay-start-dark-large.png`. The simulator was restored to light appearance and standard app text size. This is targeted simulator evidence; full-suite, physical-device, VoiceOver and landscape checks were not performed for this change. Floating controls can cover website content until collapsed; they do not reserve layout space.

### Direct Share refinement

Share now sits left of History and Settings in the floating top-right capsule. The duplicate Add/Remove bookmark menu item is removed; current-page saving remains inside Bookmarks. The leading Page actions menu appears only for media/download actions.

The targeted destination test passed on iPhone 18 Pro / iOS 27, including bookmark add/remove, History/Settings navigation, direct native share-sheet presentation and dismissal: `/tmp/harbor-controls-build/Logs/Test/Test-Harbor-2026.10.07_18-04-18--0400.xcresult`. Inspected the updated light-mode browser capture at `/tmp/harbor-share-review/controls-light.png`. Earlier attempts used unsuitable assertions for the system share sheet and were superseded by the passing check against the observed native navigation bar. No additional full-suite or hardware verification is claimed.

## Bookmark names and folders — 2026-10-07

New bookmarks save immediately with a page-title fallback, then request a bounded, structured name from Apple Foundation Models when available. Only title, hostname and URL path are used; query strings, credentials and fragments are excluded. Generation errors keep the fallback. Manual renames, deletions and profile deactivation cancel pending suggestions. Folder moves do not invalidate a pending name suggestion.

Named folders support creation, rename, navigation, saving into the current folder and moving bookmarks. Deleting a folder moves its pages to Unfiled. Root search matches names, URLs and folder names across folders. Folders are currently single-level and profile-scoped. Existing archives and durable preferences without folder fields decode successfully.

Simulator build and 32 unit tests passed, including legacy decoding, persistence, profile isolation, folder deletion, invalid destinations and stale name suggestions. Three distinct UI tests passed: bookmark rename; folder create/save/move/delete; browser destinations at accessibility text size. The latter two passed again in actual simulator dark appearance after final styling changes. Light rename and dark folder/accessibility screenshots were inspected. Results: `/tmp/harbor-bookmark-build/Logs/Test/Test-Harbor-2026.10.07_18-11-34--0400.xcresult` and `/tmp/harbor-bookmark-build/Logs/Test/Test-Harbor-2026.10.07_18-13-24--0400.xcresult`.

Actual Foundation Models generation quality and latency still require a supported physical device with Apple Intelligence available. Automated tests bypass generation and exercise persistence and stale-result safeguards deterministically.

### Explicit bookmark-name choices and rename suggestions — 2026-10-07

Supersedes automatic name application above. New bookmarks retain their saved title while an inline spinner says “Suggesting a name…”. Completed suggestions require Use name or Keep original. Generation failures show dismissible feedback without changing the title. The native rename sheet offers Suggest nickname; accepting fills only the editable draft, Save commits it and Cancel discards it. Suggestions and generation status are transient; app relaunch retains the last explicitly saved name. Profile deactivation, manual saving, deletion and rejection clear pending work.

Six WebKit/model tests passed, including explicit acceptance, rejection, generation failure, cancellation, deletion/recreation, folder moves and profile deactivation. Four targeted UI cases passed across runs: ordinary manual rename; folder organization; suggestion progress/rejection and rename draft acceptance/Cancel/Save; the same suggestion flow in actual dark appearance with accessibility-medium text. Light and dark screenshots were inspected. Initial test-only failures (loading accessibility element type and duplicated button identifiers behind the rename sheet) were corrected before the passing runs. Final UI results: `/tmp/harbor-bookmark-build/Logs/Test/Test-Harbor-2026.10.07_18-35-25--0400.xcresult` and `/tmp/harbor-bookmark-build/Logs/Test/Test-Harbor-2026.10.07_18-36-36--0400.xcresult`.

UI tests use a DEBUG-only deterministic naming fixture, and model tests inject controlled results. Actual Apple Intelligence generation quality and latency remain unverified on physical hardware.
