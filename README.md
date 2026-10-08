# Harbor

A small, persistent iPhone browser built with SwiftUI and Apple’s WKWebView. Harbor pairs the selected Horizon identity—navy water, warm reflected sunlight, and the supplied Harbor mark—with native Liquid Glass controls. It has no third-party runtime dependencies, analytics, telemetry, advertising SDKs, or crash-reporting SDKs.

## Run

1. Open `Harbor.xcodeproj` in **Xcode 27.0** (iOS 27 SDK). The deployment target is iOS 26.0; the initial device family is iPhone.
2. Choose the **Harbor** scheme and an iPhone simulator, then Run.
3. For a physical iPhone, select your development team in Signing & Capabilities. The bundle ID is **`com.arjunakankipati.harbor`**. The project includes the development team ID; signing credentials remain local.
4. Build and test with Product → Test. No package installation is needed.

The existing `assets/HarborIcon/Harbor.icon` is the app’s Icon Composer source. It is referenced directly by the Xcode project; the pre-existing PNG previews are not substituted for it.

`project.yml` is an optional XcodeGen source for regenerating the committed project (`xcodegen generate`). XcodeGen is a development tool, not an app dependency. Build outputs and personal Xcode state are ignored. No remote repository is configured.

```sh
xcodebuild -project Harbor.xcodeproj -scheme Harbor \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

## What works

- Combined address/search entry, HTTPS for entered domains, DuckDuckGo by default, Google and Bing options.
- Back/forward gestures and buttons, reload/stop, sharing, and popup-created tabs.
- New, close, switch, search and restore tabs; undo the most recent close; saved page previews.
- Background tabs unload automatically to a memory budget scaled to the device, and restore their history, scroll position and form contents when reopened.
- Local history with search and deletion, bookmarks, recent pages and favorites on the start page. New bookmarks keep the page title while showing “Suggesting a name…”; on-device suggestions from Apple Foundation Models appear with Use name and Keep original choices. Nothing is renamed automatically. The rename editor also offers Suggest nickname, which fills the draft only when accepted and requires Save to commit. Unavailable suggestions leave names unchanged. Create named folders, save directly into a folder, and swipe or long-press bookmarks to rename or move them. Search includes bookmark names, addresses and folder names. Deleting a folder moves its bookmarks to Unfiled. Folders are currently one level deep and stay within their profile. Naming uses only the title, hostname and URL path, with no cloud service or extra page fetch.
- Bundled WebKit tracker rules, tracking-parameter cleaning, and persistent per-host blocking exceptions.
- Per-site data removal and explicit all-site browsing-data clearing.
- WebKit audio/video, native full screen, and configured support for PiP and AirPlay where permitted.
- `WKDownload` support for download links, attachment responses and unsupported MIME types; completed files open the iOS Share Sheet, including Save to Files.
- Website JavaScript alert/confirm/prompt panels. User-activated external links require confirmation before handing off to iOS.

There are no invented favorites, visit counts, or protection statistics. Tab groups are future scope.

## Architecture

| Area | Responsibility |
| --- | --- |
| `App/` | SwiftUI entry point |
| `Models/` | Codable tab, history, bookmark, settings and archive records |
| `Browser/BrowserModel.swift` | Main-actor tab/session ownership, persistence, settings, browsing data |
| `Browser/TabSession.swift` | One resident WKWebView, navigation/UI delegates, observations, media status and preview |
| `Browser/AddressResolver.swift` | URL versus search interpretation |
| `Browser/DownloadManager.swift` | Native WebKit downloads and temporary files |
| `Media/MediaPolicy.swift` | Small, explicit WebKit media configuration |
| `Privacy/` | JSON rule compilation/application and conservative URL cleaning |
| `Persistence/BrowserStore.swift` | Versioned, atomic native JSON snapshot |
| `Views/` | Browser chrome, Horizon start page, tabs, library and native sheets |

Native Codable persistence keeps this small app understandable and uses atomic writes for each preferences and session file. These files are independent snapshots, not a cross-file transaction. SwiftData is not required for these simple bounded records. History is capped at 3,000 entries. The versioned format provides a migration boundary. An unreadable archive is left untouched and reported, rather than silently overwritten.

## Sessions and memory

Every profile owns a persistent `WKWebsiteDataStore(forIdentifier:)`; only a migrated original profile retains `WKWebsiteDataStore.default()` to preserve existing logins. Cookies, local storage, caches and website sessions belong to WebKit; Harbor does not serialize or manually recreate cookies. Sites may expire logins, impose third-party storage restrictions or require sign-in again. A persistent store cannot promise permanent authentication.

Harbor saves tab IDs, URLs, titles, recency and the selected tab, plus settings, history, bookmarks and site exceptions. Changes are coalesced for 250 ms and flushed when the scene becomes inactive. Relaunch restores the selected tab; other tabs load lazily when selected. Back/forward lists, DOM state, scroll position, unsaved forms, in-memory JavaScript and media position are not serialized.

The normal target is five resident web views. Recent views are preferred; the selected view, loading pages, full-screen views and views reported as playing media are protected from ordinary eviction. Memory warnings tighten the target to one and discard previews; inactive loading views may then be released, but selected, playing and full-screen views remain protected. This is a soft target: several active players or loading pages may exceed it. iOS can still terminate content processes under pressure. Harbor offers reload after process termination instead of pretending the page survived.

Resident views remain attached under the selected page and are hidden from interaction/accessibility when inactive. The tab switcher is a sheet, so opening it does not intentionally stop media. Native `requestMediaPlaybackState()` is sampled every four seconds and before eviction. The periodic check also trims idle views after loading finishes. That is a coarse observation, not a guaranteed description of every remote player. Closing a tab explicitly pauses its media. There is also Pause media in the More menu when playback is reported.

## Profiles

Use the profile icon beside the address field, **More → Profiles**, or **Settings → Profiles** to create, switch, rename or delete profiles. Each owns its tabs, selected tab, recently closed tab, history, bookmarks, search/privacy settings, site exceptions, WebKit website data, and temporary downloads. Profile names and icons are editable. The last remaining profile cannot be deleted.

Under **Profiles → When you return**, choose a default profile and **Return after**. The initial setting is **Never**; enable it and enter 1–10,080 minutes to return to the default profile after that long in the background. Shorter absences retain the current profile. The timestamp is saved on background entry and checked on foreground return and process launch, so system eviction and manual termination follow the same elapsed-time rule. Being inactive briefly for a permission prompt does not start the timer. The setting does not switch profiles during active browsing or erase any browsing data.

Switching saves the outgoing archive and releases its web views; tabs restore lazily when you return. Unsaved forms, back/forward stacks, media position and other in-memory page state do not survive a profile switch. Downloads continue under their original profile and can be shared when returning to it. Clearing or deleting that profile cancels its downloads. Exported files remain outside Harbor’s control.

Profile metadata lives in `Application Support/Harbor/profiles.json`; each profile stores bookmarks/settings in `Profiles/<UUID>/preferences.json` and tabs/history in `Profiles/<UUID>/DeviceOnly/session.json`. The background timestamp lives in `DeviceOnly/profile-session.json`, separate from the registry. Existing installations migrate their archive into **Personal** and retain their existing WebKit store. Old mixed `browser.json` archives are excluded from backup before migration and removed only after the replacement files have committed successfully (and the registry, for original single-profile migrations). Interrupted migrations retry from the original; unreadable legacy files remain excluded and recoverable. Corrupt metadata is reported and left untouched. Failed profile deletions remain visible as **Unfinished deletions** with a retry action.

Profiles isolate Harbor’s browsing data, not iOS identities: device permissions, password providers, the clipboard, exported files and the network connection remain system-level facilities. To lock a profile, open its edit screen and enable **Require Face ID** (Touch ID or device authentication on other devices). Harbor authenticates with the system biometrics or device passcode before enabling/disabling protection or deleting a protected profile. Protected profiles lock on launch, when switched away from, and when Harbor enters the background; automatic return to a protected default also opens the lock screen. Anyone who can authenticate as the device owner can unlock any protected profile. This is an app access lock, with no separate encryption key for profile data.

The app-switcher preview follows the profile's unlock session: an unlocked profile with a lock delay shows its page, while locked profiles and profiles set to lock immediately show the Harbor cover. iOS can retain a previously captured preview while Harbor is suspended, including beyond the lock delay; the lock is checked before browsing resumes. Choose **Immediately** to hide the page preview whenever leaving Harbor.

## Privacy model

`Resources/tracker-rules.json` is compiled using `WKContentRuleListStore`. Initial browsing waits for compilation. If compilation fails, the UI reports protection unavailable and browsing remains available. The small ruleset covers third-party Google Analytics, DoubleClick, Google Syndication, Meta pixel endpoints, AdsRvr, ScorecardResearch, Hotjar and Segment. Rules mostly target script, image, raw and ping requests rather than documents or media. Broad Google/Meta/CDN/authentication domains are deliberately not blocked wholesale.

Rules are not a full EasyList/EasyPrivacy engine, are not updated remotely and cannot eliminate fingerprinting, first-party tracking, all ads or tracking embedded in required content. Larger curated JSON rule lists can replace this resource later. Review source licensing and compatibility before importing a list.

A site exception is an **exact normalized hostname**, not every subdomain. Rule lists are applied to each web view before top-level navigation and updated when settings change. A change does not undo already-loaded scripts; the privacy sheet offers an explicit reload that may discard form input. Disabling protection is the compatibility escape hatch for video and login issues.

No blocked-request counter is displayed. Public WebKit content-blocking APIs do not offer a reliable per-page count for this implementation. A loaded ruleset means rules are installed, not that a specific number of requests were prevented.

Tracking cleaning removes only known keys, including `utm_*` entries enumerated in the cleaner, `gclid`, `dclid`, `fbclid`, `msclkid`, `mc_cid` and `mc_eid`. It preserves remaining parameter encoding/order and fragments. Signed/tokenized URLs and recognized media extensions are left intact. Only top-level GET requests are rewritten; POSTs, subresources and popup opener requests are not rewritten. This intentionally misses some tracking to avoid breaking signatures, media and authentication.

Harbor is **not an anonymity tool or a private/incognito browser**. Profiles, bookmarks, settings and site exceptions are eligible for normal device backups. Tabs, history, tab recency and the background timestamp persist locally in explicitly backup-excluded Application Support directories; they are not placed in purgeable Caches. Restoring without these files opens a new tab with no history. Website cookies and storage remain managed by WebKit; Harbor does not copy them or alter private WebKit files. Older backups may still contain browsing data. Backups do not provide cross-device sync or guarantee restored website logins. Websites and network operators can still observe activity. There is no app-operated proxy, VPN or sync service.

## Website data and security

Per-site clearing asks WebKit for domain records and removes matching cookies/storage. WebKit may report registrable domains, so related subdomains can also be affected; exact-origin deletion is not guaranteed. Pages affected by deletion are stopped and require an explicit reload. All-site clearing is scoped to the current profile: it closes its tabs and removes its history, cookies, cache and website storage; bookmarks, settings and exceptions remain. Temporary downloads are removed and active downloads are cancelled. Leftover temporary downloads from an earlier process are also removed when their profile is first opened.

TLS validation, App Transport Security and the standard user agent are unchanged. There is no trust-challenge bypass, arbitrary-load exception, DRM workaround, injected remote script or universal third-party cookie override. Plain HTTP sites may be restricted by platform transport policy. Unknown schemes from automatic redirects or subframes are not launched. Supported user-activated external links go through iOS after confirmation; unavailable handlers produce an error.

Camera and microphone usage descriptions support websites that request permission; permission remains under iOS/WebKit control. Harbor neither pre-grants access nor records media itself. File upload controls remain WebKit’s native controls.

## Media

Configuration explicitly enables inline playback, native Picture in Picture and AirPlay. All media types require user interaction. Websites must also use suitable markup/player APIs; configuration alone cannot force inline playback, PiP, AirPlay or autoplay. Native video controls and system routes are preserved. Browser chrome hides while WebKit reports native full-screen mode.

No custom player, audio session override, user-agent spoof or background-audio entitlement is installed. Background/lock behavior is therefore governed by iOS/WebKit and may pause audio/video. Adding `UIBackgroundModes = audio` would require a deliberate product decision, legitimate background-audio use, device testing and consideration of battery/resource behavior; it would still not guarantee that every website continues playback.

DRM support, codecs, HLS, embedding permissions, signed media, provider policy and user-agent checks vary by site/device. A website working in Safari does not establish that it works identically inside WKWebView. Some services may reject embedded browsers or require their own app. Harbor does not bypass those restrictions.

Downloads use native `WKDownload`, including attachment headers and `download` links. Normal playable media remains inline unless the website requests a download. Temporary files are not a durable download library; use Save to Files. Resume, background downloads and a full download history are future improvements.

## Validation and manual media checklist

See [validation results](docs/VALIDATION.md) for the actual run evidence. Automated tests cover logic, WebKit configuration and rules, shared persistent cookies, tab metadata, and selected UI flows. The local test page and synthetic H.264/AAC sample make basic playback checks reproducible without a network. Debug launch flags `--uitesting --reset --fixture` use separate test metadata and open that fixture; they are inactive in Release. They use dedicated named WebKit profiles as well as separate metadata, so they do not share the user’s website sessions.

Record device, iOS version, site/page URL, date, blocking on/off, outcome and any reproducible error for each check. An unchecked box is **unverified**, not a compatibility claim.

- [ ] YouTube: open a video; user-initiated play, pause, seek, inline and embedded playback.
- [ ] Vimeo: direct page and embedded player.
- [ ] Twitch: live stream, controls and account/age prompts where relevant.
- [ ] HTML5 `<video>`: play/pause/seek and native controls.
- [ ] HTML5 `<audio>`: play/pause and duration updates.
- [ ] HLS: live and on-demand streams; seek where supported.
- [ ] AirPlay: real receiver, route out/in, controls after disconnect.
- [ ] Picture in Picture: enter/exit when offered; restore the original tab.
- [ ] Full screen: repeatedly enter/exit; rotate; confirm navigation and tab identity survive.
- [ ] Switch tabs during audio/video; return; open/dismiss the tab switcher without intentionally stopping playback.
- [ ] Close the playing tab and confirm it stops; retain another tab’s playback.
- [ ] Lock/unlock the physical device; record whether playback pauses or resumes.
- [ ] Background/foreground the app, with and without PiP; record actual behavior.
- [ ] Media-heavy pages with blocking **on**, then repeat with a site exception and reload.
- [ ] Signed media URLs and downloadable media attachments.
- [ ] Website sign-in, several tabs, app termination/relaunch, restored URLs and retained login.
- [ ] Memory warning and WebKit process termination; confirm honest reload recovery.
- [ ] Light/dark, Dynamic Type, VoiceOver, Increase Contrast and Reduce Transparency.

Do not enter personal credentials into an automated fixture. Use an account you choose for the physical-device sign-in check.

## Platform boundaries and next steps

Safari extensions are not automatically available in this embedded browser. Harbor uses the system WKWebView engine; it does not bundle another renderer. Harbor registers HTTP/HTTPS URL schemes and opens incoming web links in new tabs after applying profile-return and lock rules. Links received while locked are held in memory for that profile until it is unlocked; switching profiles does not transfer them. Pending links are lost if the app is terminated. Default-browser selection still requires Apple approval and provisioning for the `com.apple.developer.web-browser` entitlement, which is not yet configured. No claim is made about eligibility for alternative-engine entitlements.

Future work: tab groups and iPad layouts; encrypted/private iCloud sync; Face ID; reader mode; custom rule lists; password-manager integration; per-site JavaScript, cookies, autoplay, media permissions and user-agent settings; HTTPS-only mode; downloadable-file management; opt-in background-media policy. These are not inactive controls pretending to be implemented features.

### Apple/WebKit references

- [WKContentRuleList](https://developer.apple.com/documentation/webkit/wkcontentrulelist) and [content-blocker format](https://webkit.org/blog/3476/content-blockers-first-look/).
- [WKWebView media playback state](https://developer.apple.com/documentation/webkit/wkwebview/requestmediaplaybackstate(completionhandler:)).
- [Picture in Picture configuration and related media preferences](https://developer.apple.com/documentation/webkit/wkwebviewconfiguration/allowspictureinpicturemediaplayback).
- [Persistent website data store](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/default()).
- [Native Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).

## Release 0.1.0

The initial Harbor release includes persistent tabs and website storage, tracker blocking, per-site exceptions, history, bookmarks, native media playback, and the Horizon interface. See [validation notes](docs/VALIDATION.md) for tested behavior and remaining device checks.

To archive and upload to TestFlight, configure the git-ignored `.release.env` using `.release.env.example`, then run `./release.sh` from a clean checkout. The script regenerates the Xcode project, runs tests, archives, uploads, and creates a build-specific Git tag after a successful upload. Use `./release.sh --no-upload` to export locally. The local `v0.1.0` tag identifies the source release; TestFlight availability requires a successful upload and App Store Connect processing.

If simulator tests fail before launching with `Unknown application display identifier` or `No such process`, select another installed simulator using `TEST_DESTINATION='platform=iOS Simulator,id=<UDID>'` in `.release.env`. List available IDs with `xcrun simctl list devices available`. An interrupted test run may leave an incomplete result bundle; it does not imply that an archive or upload succeeded.

## License

All first-party code in this repository is licensed under the [Mozilla Public License 2.0](LICENSE), including the app, tests, scripts, website source, and build and configuration files. See [NOTICE](NOTICE) for scope and third-party exceptions.

When distributing modified MPL-covered code, make the covered source available under MPL 2.0. Separate files containing no MPL-covered code may use other licenses.

The Inter font retains its [SIL Open Font License 1.1](Harbor/Resources/Inter-LICENSE.txt). The Harbor name, logos, and brand artwork are not covered by the code license.
