# Harbor public release acceptance

Work through this checklist on the exact TestFlight build intended for release. Check an item only after it passes. Record failures and untested cases below. The App Store page is ready; these checks cover the app and release candidate.

## Run details

- Version and build:
- Source commit:
- Tester and date:
- iPhone models and iOS versions:
- Installation: fresh / upgrade from:
- Automated test results:

Run core checks on physical iPhones covering the oldest and latest supported iOS versions, including a smaller screen where available. Test both a fresh install and an upgrade containing real browsing data. Use test accounts you control. For failures record the URL, profile, protection settings, steps, expected and actual behavior, and a screenshot or recording. Do not include passwords or sensitive browsing data in committed evidence.

## Installation and upgrade

- [ ] Fresh install opens with one usable profile and no invented browsing data.
- [ ] Icon, display name, launch appearance, and displayed version are correct.
- [ ] Upgrade preserves profiles, bookmarks, folders, settings, tabs, and groups.
- [ ] Existing website logins survive where the website permits.
- [ ] Repeated launch, background, force-quit, and relaunch do not crash or stall.
- [ ] Reboot, unlock the phone, and reopen Harbor; saved data is accessible.

## Navigation and websites

- [ ] Bare domains, HTTPS URLs, paths, queries, fragments, and searches route correctly.
- [ ] Spaces, Unicode, dotted search terms, and long pasted URLs behave correctly.
- [ ] DuckDuckGo, Google, and Bing work; engine selection persists per profile.
- [ ] Links, redirects, and same-page anchors work; the address matches the destination.
- [ ] Back, forward, swipe navigation, reload, and stop work repeatedly.
- [ ] Load A, disconnect, navigate to B, reconnect, and retry; B is retried instead of A.
- [ ] Retry a failed form submission; method and body are preserved without silent conversion to GET.
- [ ] Offline recovery and Wi-Fi/cellular transitions preserve tabs.
- [ ] Invalid TLS certificates are not silently accepted.
- [ ] HTTP pages show the not-secure warning in the expanded and collapsed address bar; HTTPS pages do not.
- [ ] Ordinary and popup/redirect-based sign-in work; logins survive relaunch where permitted.
- [ ] Password AutoFill, copy/paste, text selection, file uploads, and forms work.
- [ ] JavaScript alert, confirm, and prompt accept/cancel correctly; closing or switching tabs does not hang.
- [ ] Long-press open, new tab, copy, and Open in Another App actions match their labels; Open in Another App shows the share sheet.
- [ ] External app links ask for confirmation; cancellation stays in Harbor.

## Default browser

- [ ] TestFlight-installed Harbor appears in the system default-browser selector.
- [ ] The Settings shortcut opens system settings.
- [ ] Links from another app work with Harbor running, backgrounded, and terminated.
- [ ] Incoming links do not expose a locked profile before authentication.
- [ ] Switching away from a locked profile does not transfer its pending link to another profile.
- [ ] Incoming links after the return timeout use the intended profile.
- [ ] Repeated external links do not create an opening loop.

## Tabs and groups

- [ ] Create, select, close, and undo-close tabs; closing the last leaves a usable start page.
- [ ] Closing a playing tab stops its media.
- [ ] Search titles/addresses, clear search, and inspect empty results.
- [ ] Reorder in both directions; order and selection survive relaunch.
- [ ] Open 40–60 tabs and revisit old/recent tabs without crashes or wrong previews.
- [ ] Unloaded tabs restore URL, back/forward history, scroll, and ordinary form state where supported.
- [ ] Create, rename, select, and delete groups; deleting a group keeps its tabs.
- [ ] Move tabs into/out of groups; All Tabs and scoped search show correct contents.
- [ ] New and popup tabs inherit the intended group.
- [ ] Groups and selected scope survive relaunch and remain profile-specific.
- [ ] Disable tab restoration; relaunch opens a fresh tab while keeping bookmarks/settings.

## Profiles and locks

- [ ] Create, rename, change icons, switch, and delete profiles.
- [ ] Delete the active profile while a page is loaded; Harbor switches to the fallback, removes the deleted profile, and shows no unfinished deletion or retry row.
- [ ] Different profiles hold separate logins to the same website.
- [ ] Tabs, groups, history, bookmarks, search settings, and exceptions stay isolated.
- [ ] Enabling/disabling protection and changing its delay require authentication.
- [ ] Face ID/passcode success unlocks; failure/cancel leaves the profile locked.
- [ ] Protected profiles lock on cold launch and when switched away from.
- [ ] Immediate locking hides app-switcher content, including sheets and fullscreen video.
- [ ] Delayed locking allows early returns and requires authentication after expiry.
- [ ] Verify the documented preview limitation: iOS may retain a visible delayed-lock snapshot while suspended.
- [ ] Return-to-default works for Never, below/above timeout, and force-quit/relaunch after timeout. Confirm the displayed duration before timing; include the five-minute minimum.
- [ ] A protected default profile opens locked after automatic return.
- [ ] Protected deletion requires authentication and leaves other profiles intact.
- [ ] The last profile cannot be deleted.

## History and bookmarks

- [ ] Actual visits appear; history search and opening results work.
- [ ] Delete one visit, filtered selections, and all history with correct scope.
- [ ] Deletions persist after relaunch; tabs/logins remain as the confirmation promises.
- [ ] Add, open, rename, and delete bookmarks; changes persist.
- [ ] Create/rename folders and move bookmarks; deleting a folder moves bookmarks to Unfiled.
- [ ] Search matches bookmark titles, addresses, and folder names.
- [ ] On supported hardware, Apple Intelligence suggestions complete or fail gracefully.
- [ ] Use name applies a suggestion; Keep original preserves the original.
- [ ] Rename suggestions change only the draft; Cancel discards it and Save commits.
- [ ] Deletion/profile switching during generation causes no late unwanted rename.
- [ ] Without Apple Intelligence, saving and manual naming still work.

## Privacy and clearing

- [ ] Privacy Policy opens https://harbor.arjunakankipati.com/privacy/ in a modal over Settings; Done or swipe-to-dismiss returns to Settings without adding a browser tab.
- [ ] Blocking and parameter cleaning preferences persist per profile.
- [ ] Representative sites work with protection; exceptions plus reload provide a compatibility escape hatch.
- [ ] Exceptions apply to exact hostnames, not every subdomain.
- [ ] Known tracking parameters are removed on supported paths; functional parameters/fragments survive.
- [ ] Signed links, login redirects, and submitted forms still work.
- [ ] Per-site clearing removes login/storage and pauses affected pages; check related subdomains.
- [ ] Paused pages stay paused after backgrounding Harbor and switching tabs, until Reload or a new address.
- [ ] All-data clearing removes that profile's tabs, groups, history, website data, previews, and temporary downloads.
- [ ] Bookmarks, settings, and exceptions remain; other profiles are unaffected.
- [ ] Relaunch and undo-close do not resurrect cleared browsing data.

## Downloads and sharing

- [ ] Download PDFs, images, ordinary files, and authenticated attachments.
- [ ] Save to Files and reopen; names and contents are correct.
- [ ] Download multiple files concurrently while Settings is open; every file remains available in Downloads.
- [ ] Files with identical suggested names remain separately accessible and intact.
- [ ] Switching profiles during download preserves ownership and access on return.
- [ ] Failure produces feedback and clears the active indicator.
- [ ] Clearing/deleting the profile cancels downloads and removes temporary files.
- [ ] Page sharing supplies the correct URL; dismissing it leaves browsing usable.
- [ ] Force-quit during download; relaunch makes no false completion/resume claim.

## Media

- [ ] YouTube watch pages and actual embeds support play/pause/seek/fullscreen.
- [ ] Vimeo, Twitch, HTML5 audio/video, and HLS play with usable controls.
- [ ] Reddit GIF-style videos recover after tab switching and background/return.
- [ ] Muted autoplay works where allowed; audible media does not unexpectedly autoplay.
- [ ] Tab switching and opening/dismissing the switcher do not freeze playback.
- [ ] Repeated fullscreen entry/exit and rotation restore usable controls.
- [ ] PiP enters/exits where offered and returns to the correct tab.
- [ ] AirPlay connects/disconnects with a real receiver and recovers controls.
- [ ] Record lock/unlock and background behavior with/without PiP.
- [ ] Repeat problematic sites with blocking disabled or an exception.

## Permissions and accessibility

- [ ] Camera/microphone permission allow/deny paths work and identify the requesting site appropriately.
- [ ] Revoking permissions in Settings does not crash or hang Harbor.
- [ ] Light/dark, portrait/landscape, keyboard, and largest text leave controls reachable.
- [ ] VoiceOver can operate navigation, tabs, groups, profiles, history, bookmarks, dialogs, and locks.
- [ ] Reduce Motion, Reduce Transparency, and Increase Contrast preserve usability.
- [ ] Collapsing/restoring chrome does not hide essential page actions or unexpectedly open the keyboard.
- [ ] Browse 30–60 minutes with many tabs/media pages; check crashes, freezes, heat, and excessive battery use.

## Release decision

- [ ] Full automated suite passes on the final commit; failures/skips are reviewed.
- [ ] Signed archive validates and the candidate finishes App Store Connect processing.
- [ ] The distribution build contains the default-browser entitlement.
- [ ] Physical-device checks above are complete; exceptions have explicit dispositions.
- [ ] No unresolved crash, data loss, cross-profile leak, lock bypass, or broken core navigation.
- [ ] Public privacy URL and support mailbox work; public copy matches actual behavior.

| Check | Result or issue | Evidence | Resolution or accepted limitation |
| --- | --- | --- | --- |
| | | | |

Release decision and date:
