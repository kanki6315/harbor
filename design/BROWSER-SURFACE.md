# Harbor browser surface

Status: Horizon direction implemented in native SwiftUI. Mode: Operate.

## Decision and evidence

The user said, “I like harbor too. Let's save that and update any design documentation around it before we make any code itself,” following the recommendation of Horizon's start page with Collections' tab organization. This record interprets that as acceptance of that recommended direction. Harbor is the app name; Horizon and Collections are concept labels, not product names.

- Primary visual reference: [Horizon](../.impeccable/mocks/harbor-glass/horizon.png).
- Organization reference: [Collections](../.impeccable/mocks/harbor-glass/collections.png).
- Brand source: [Harbor identity](brand/harbor-identity.png).
- Global design authority: [DESIGN.md](../DESIGN.md).

The combined direction is implemented in `Harbor/Views`. Collections is an organization reference, not approval of every pictured toolbar. Current remains an unselected alternative. The existing Harbor icon is referenced directly by Xcode; still Horizon scenery and the supplied mark geometry are drawn with Canvas.

## First viewport

The start page opens with Harbor's blue horizon and warm reflected sunlight, the Harbor mark and wordmark, followed by a Continue browsing item when history exists and Favorites when real bookmarks exist. Keep the bottom search/address entry reachable. The scenic area establishes identity but must yield space to content at smaller sizes and larger text settings.

Empty state: omit the resume card if no page can be resumed; show a brief invitation to search. Never seed mock favorites as though the user created them. First launch opens this start page; later launches restore the selected browsing tab when session restoration is enabled.

## Task sequence

Launch or restore → enter a domain/search or resume → browse → switch/search open tabs → return to the selected page. The tab switcher is a task surface, not the start page presented on every app launch.

The tab switcher offers All Tabs and optional named groups within the current profile, with local title/address search, recognizable previews, titles, domains and an unmistakable selected state. Search is prominent enough to make 40+ tabs manageable. Use the implemented single-column cards with shorter previews at accessibility text sizes. A tab may be selected without reordering the collection. Close supports Undo; closing the final tab opens the start page.

### Tab groups

The native group selector above the existing card grid offers All Tabs, each named group with its count, and New group. All Tabs shows one card per named group, including empty groups, followed by individual ungrouped tabs. Group cards show the name, tab count, up to three member titles at standard text sizes, and whether they contain the selected tab. Tapping a group card opens its scope. Search matches group names and member titles/addresses as well as ungrouped tabs. Selecting a group filters the grid and search, clears the previous search, and shows both the group count and total tab count. Selecting a scope does not switch the active page. Empty groups explain how to create a tab or move one from All Tabs.

Create and rename use a native Form with Group name and Save/Cancel; blank or whitespace-only names cannot be saved. A tab's visible ellipsis menu and long-press menu offer Move to group, New group and, for members, Remove from group. Creating from a tab's menu moves that tab into the new group; creating from the selector starts an empty group. New tabs join the selected group; website-created popups inherit the current tab's group. A tab belongs to at most one group, and moving it preserves the page session and tab order.

The selector offers Rename group and Delete group for the selected group. Deletion requires the explicit “Delete group, keep tabs” confirmation; its message says the tabs remain open in All Tabs. No close-members action is provided. Groups, membership and selected scope persist with the profile's backup-excluded session data. Older archives open without groups. Clearing all browsing data also removes the current profile's groups.

This extends the incumbent Operate surface: native Menu and Form controls, SF Symbols, system headline/caption styles, semantic backgrounds and regular material for the card menu. It retains the existing card grid, preview geometry, selected border/checkmark and accessibility reflow. No new identity, tokens or artwork are introduced.

### Tab order and saved previews

Drag a preview onto another card to change its position, or open Reorder for a native list with persistent drag handles. Reorder shows all tabs even when the grid is filtered. Both surfaces expose Move earlier and Move later accessibility actions. Order is saved with the profile's tab archive; moving a tab preserves the selected tab. The existing two-column grid and accessibility-size single-column cards remain unchanged.

Tab options includes Unload background tabs. It releases eligible WebKit views while retaining the tab records and their last saved previews; the selected tab, playing media, fullscreen pages and loading pages stay open. An unloaded website card displays a moon symbol with “Unloaded.” Selecting it creates a page session and restores WebKit's saved interaction state (back/forward history, scroll position and form contents) when one was saved for that address; otherwise it reloads the URL. The page itself still reloads: JavaScript state and an offline copy are not preserved. Close remains a separate action that removes the tab and supports Undo close.

Successful page snapshots are saved as local JPEG previews beside each profile's archive, separate from the tab JSON and excluded from backup. Cards read the saved preview; a snapshot stays in memory only when it could not be saved; otherwise Harbor's existing placeholder appears. Saved previews can survive WebKit view unloading and app relaunch; capture or disk-write failures retain the placeholder fallback. Unloading uses the last available preview rather than promising a fresh capture at that moment. Browsing-data clearing removes saved previews, including when clearing one site's data; stale files are pruned on restoration and superseded Undo-close previews are removed. Saved interaction state follows the same profile scoping, file protection, backup exclusion, clearing and pruning rules, and is only kept for HTTP(S) tabs.

Harbor also unloads background tabs automatically. The live-page budget scales with device memory (2–8 pages) and drops to two when iOS reports little headroom, or to the selected page after a memory warning. The least recently visible tab goes first. Loading, full-screen and playing tabs are skipped and rechecked when they finish loading or leave full screen, and every 20 seconds while media plays. Entering the background unloads eligible background tabs and saves the visible page's state. A background page whose WebKit process ends is unloaded rather than left as a dead view. The visible page reloads automatically once; a second termination within 30 seconds shows the reload message.

This is a native Operate refinement using the incumbent semantic colors, SF Symbols, typography and materials. No new visual world, design tokens or shipping artwork is introduced. Implementation sources are `TabSwitcherView.swift`, `BrowserModel.swift`, `TabSession.swift` and `BrowserStore.swift`; behavioral and visual verification is recorded separately after review.

## Controls and privacy

Use one native Liquid Glass row at the bottom over website content, with a transparent outer surround: Back, flexible address/search capsule, tabs and Browser menu. There is no top control overlay. Controls use semantic primary tint while untinted native regular glass follows the system appearance; Reduce Transparency retains the opaque semantic background fallback. The flanking actions have separate 44pt-wide targets and are 48pt high. The address capsule includes the profile shortcut, field and contextual reload/stop action. Site protection is available in Browser menu. At accessibility Dynamic Type sizes reload/stop is accessed through Browser menu so the field retains space; outer margins narrow from 12pt to 8pt. Editing hides the flanking actions and expands the address capsule across the row with a Go action. The tab count is centered in a 24pt rounded outline and scales down for larger counts.

Browser menu contains Share page when a URL exists, Bookmarks, History, New tab, Forward, reload/stop, Site protection, Profiles with the current profile name as a native menu subtitle, Settings, and available media/download actions. Share opens the native share sheet. The Bookmarks screen exposes Bookmark this page / Remove bookmark for this page above the saved list. Profiles also remains in Settings. The address capsule has a 44pt-wide icon-only profile shortcut; the accessible label retains the full profile name. It hides during address editing and opens Profiles directly.

Scrolling down a website minimizes the row into a tiny centered host-only glass pill. Its `.caption2.weight(.medium)` label is capped at `.xxxLarge`, truncates in the middle and is at most 112pt wide normally or 180pt at accessibility text sizes. The small visible capsule has a minimum 44pt touch target extending upward. Lower it toward the home indicator by `min(12, max(0, bottomInset - 20))` points, allowing up to 12pt only when the safe area has room. Its accessible name includes the site and current profile. Tapping the pill restores the controls without opening the keyboard; switching tabs also restores the expanded row.

Website views respect the top safe area and extend behind the bottom controls and home-indicator area. Measured bottom scroll insets let ordinary page-end content scroll above the controls; this overlay does not guarantee clearance for fixed CSS footers. Start-page scrolling is unclipped beneath the controls, with its background extended through the safe areas. Reduce Transparency retains opaque capsule fallbacks without a solid outer bar. Loading progress overlays the address capsule without changing its height. Native media fullscreen hides the browser controls and removes their scroll inset.

Site protection in Browser menu opens protection status and per-site controls at every text size. Protection status reads “Tracker blocking on,” “Off for this site,” or an honest unavailable/global-off state. No blocked-request counter unless it can be measured reliably. Site-data clearing explains possible sign-out. Disabling protection offers an explicit reload rather than silently discarding page input.

## Motion and material

Native transitions connect preview selection and browsing. The address capsule and compact URL pill share a native glass identity within `GlassEffectContainer`, morphing with spring responses of 0.34 seconds on collapse and 0.42 seconds on expansion, both with 0.86 damping. The neighboring action controls scale from 0.7 at their bottom edge and fade. Address editing uses a 0.38-second spring with the same damping. Reduce Motion replaces these transitions with a 120ms ease-out fade and removes the shared-glass morph and control scaling. Glass belongs in navigation and control surfaces over content; Reduce Transparency preserves the opaque capsule fallback. Keep the water artwork still; no ambient animation is required.

## Implementation and verification boundaries

The user approved the tab-group extension described above. Voice input and more advanced group-management flows remain outside the implementation. There are no seeded favorites. Native light/dark and large-text variants exist; hardware accessibility checks remain in the validation checklist. The comps are image-generated references with synthetic content, not tested UI.

At accessibility Dynamic Type sizes, the decorative horizon yields to a compact navy brand header; the protection button wraps on a solid surface and chrome margins narrow. Native Reduce Transparency fallback is implemented by `HarborGlass`.

The native review accepted the structure and Horizon fidelity and identified two contrast corrections. The address prompt and first-run supporting body now use primary at 72% opacity; the reviewer confirmed both contrast corrections resolved and issued a scoped ship verdict. The earlier transparent browser surround and centered tab-count changes received a scoped review after simulator geometry assertions, media/fullscreen/restoration regression tests and native screenshot inspection. The reserved solid strip and manual chevron implementation passed four targeted simulator tests and received a scoped finish verdict, but the user subsequently rejected its solid bar and supplied a Safari reference. That direction and acceptance are superseded by the current glass-over-content implementation, which minimizes on scroll into a centered URL pill. Three targeted simulator tests and a repeated dark-appearance test passed. The independent finish reviewer inspected the user references and seven captures and issued a scoped ship verdict for that implementation. The subsequent motion refinement passed three targeted simulator tests, including repeated collapse/restore cycles. An independent review accepted both transition directions using recording-derived samples; frame pacing and device Reduce Motion behavior remain unverified. Those scoped verdicts concern earlier control iterations and do not validate the unified bottom row or its smaller pill. This record does not claim global visual approval. The implemented tokens and component conventions are in `DESIGN.md`; build/test evidence and physical-device/site limits are in `docs/VALIDATION.md`. Preserve the selected identity in future work.

## Earlier direction contract — collapsible browser controls (superseded)

THESIS: Keep website content visible behind native glass controls; minimize the controls while scrolling down and restore them by tapping the compact URL.

OWN-WORLD: Preserve Harbor's native glass capsules, semantic content surfaces, SF Symbols and accessible touch targets. The outer browser surround stays transparent; Reduce Transparency applies to the capsules.

STORY: The earlier two-row arrangement minimized into a centered URL pill on scroll and restored on tap. The unified bottom controls contract below supersedes that arrangement. The compact pill identifies the current site and retains a minimum 44pt touch target.

FIRST VIEWPORT: The earlier address and action rows started expanded over content. The website respects the top safe area and extends behind the bottom controls. Measured scroll insets keep ordinary page-end content reachable; fixed CSS footer clearance is not guaranteed by this overlay. Loading progress overlays the address capsule without changing its height.

FORM: Narrow refinement of the incumbent Operate surface, implemented directly; no concept seed or replacement visual world. The user's Safari screenshot and explicit glass-over-content request supersede the reserved solid strip and manual side-chevron direction. There are no manual collapse or expand chevrons; the centered URL pill restores the controls.

FINISH: The glass-over-content layout received a scoped ship verdict. The subsequent motion refinement is documented, passed targeted and repeated-transition checks, and received scoped acceptance from an independent review of sampled simulator motion. Unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.

## Direction contract — profiles

THESIS: Make the current browsing context discoverable and let the user switch between isolated profiles without mixing their data.

OWN-WORLD: Extend the existing native Operate surface with SF Symbols, semantic text, grouped Forms, system sheets, navigation, pickers and destructive confirmations. Preserve Harbor’s glass browser controls and Horizon artwork.

STORY: Open Profiles from Browser menu or Settings; select a profile, create or edit its name/icon, or delete it with a scoped confirmation. Choose a default profile and a background inactivity duration, including Never.

FIRST VIEWPORT: Profiles presents the user’s real profile names, a checkmark on the current profile, edit controls and New profile. The following section contains Default profile and Return after. Explanatory text describes separation, switching and timeout behavior without suggesting device-level isolation.

FORM: A narrow functional extension of Harbor’s established native settings and browser surfaces. Direct implementation follows the agreed profile plan; no replacement visual world, concept seed or generated assets.

FINISH: Unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance. This extension creates no shipping rasters and preserves the incumbent design tokens.

Implementation/verification: Profiles is now reachable through Browser menu and Settings, superseding its earlier address-row shortcut. Grouped native Forms, SF Symbols, semantic text, system sheets, pickers and confirmations follow the incumbent component conventions; accessibility Dynamic Type stacks a labeled Edit action beneath each profile’s selection row. The independent finish review issued a scoped ship verdict for the relevant code and five simulator captures in `.impeccable/review/`: `phone-profiles.png`, `phone-profiles-dark-large.png`, `phone-profile-editor-dark-large.png`, `phone-profile-return-editor.png` and `phone-profile-timeout.png`. This documents the reviewed light, dark, large-text and return-setting surfaces, not a full-suite pass or global visual approval. The original profile review did not change `DESIGN.md` or `.impeccable/design.json`; this browser-control documentation refresh updates the Markdown only. The pre-existing stale sidecar is not regenerated as part of this scoped refinement.

## Direction contract — unified bottom controls

THESIS: Keep browsing controls in one low row, leaving more of the page visible.
OWN-WORLD: Preserve Harbor's native glass, semantic colors, SF Symbols and system type.
STORY: Back, address, tabs and menu share one row. The menu contains sharing, library, navigation, profile, protection and settings actions. Scroll down to minimize; tap the site pill to restore without opening the keyboard.
FIRST VIEWPORT: Separate 44pt-wide action targets flank a flexible 48pt-high address capsule, with no top overlay. The minimized host label uses `.caption2` capped at `.xxxLarge`, maximum widths of 112pt normally and 180pt at accessibility text sizes, and a minimum 44pt target extending upward. Lowering is safe-area-aware: `min(12, max(0, bottomInset - 20))` points. Editing expands the address field across the row. At accessibility text sizes, protection and reload/stop move to Browser menu.
FORM: User approved the three-state mockup, then requested a smaller, lower minimized pill. Native implementation preserves the approved structure; system safe areas and Dynamic Type govern exact dimensions. No new artwork ships.
FINISH: This contract records the approved structure and implemented values, not a validation verdict. Current build, interaction and visual review evidence belongs in `docs/VALIDATION.md`. This refinement creates no shipping rasters.

Finish record: independent review issued scoped ship for the unified controls after the dark-glass contrast fix. Final simulator evidence and remaining verification limits are recorded in `docs/VALIDATION.md`; the implementation adds no shipping raster assets.
