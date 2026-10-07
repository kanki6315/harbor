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

MVP uses All Tabs with local title/domain search, recognizable previews, titles, domains and an unmistakable selected state. Search is prominent enough to make 40+ tabs manageable. Use the implemented single-column cards with shorter previews at accessibility text sizes. A tab may be selected without reordering the collection. Close supports Undo; closing the final tab opens the start page.

Future groups use Collections' overview and compact in-group previews. Groups are optional, with All Tabs always available. A group count must describe its scope; distinguish “18 in Everyday” from “42 total.” Moving between groups must not require closing tabs. Group deletion must distinguish keeping from closing member tabs.

## Controls and privacy

Use native bottom address/search and action controls in Liquid Glass over website content, with a transparent outer surround. Include back, forward, reload/stop, new tab, tab switcher, share and more actions. The implemented two-capsule arrangement puts the shield, field and contextual Go/reload/stop in the first row; Back, Forward, New tab, tab count and More in the second. Editing expands the address row and hides the second row. The tab count is centered in a 27pt rounded outline and scales down for larger counts. Scrolling down a website minimizes both rows into a small centered glass URL pill; tapping the pill restores them. Switching tabs restores the expanded controls. Website views respect the top safe area and extend behind the bottom controls and home-indicator area. Measured bottom scroll insets let ordinary page-end content scroll above the controls; this overlay does not guarantee clearance for fixed CSS footers. Start-page scrolling is unclipped beneath the bars, with its background extended through the safe areas. Reduce Transparency retains opaque capsule fallbacks without a solid outer bar. Loading progress overlays the address capsule without changing its height. Native media fullscreen hides the browser controls and removes their scroll inset. Share, bookmark, history, settings and available media/download actions live in More.

An unobtrusive shield opens protection status and per-site controls. Label it “Tracker blocking on,” “Off for this site,” or an honest unavailable/global-off state. No blocked-request counter unless it can be measured reliably. Site-data clearing explains possible sign-out. Disabling protection offers an explicit reload rather than silently discarding page input.

## Motion and material

Native transitions connect preview selection and browsing. Glass belongs in navigation and control surfaces, with opaque content below. Keep the water artwork still initially; no ambient animation is required. Reduce Motion and Reduce Transparency must work without losing meaning or functionality.

## Implementation and verification boundaries

Tab groups are future scope; the selected design does not authorize implementing them now. Voice input and detailed group-management flows remain outside the implementation. There are no seeded favorites. Native light/dark and large-text variants exist; hardware accessibility checks remain in the validation checklist. The comps are image-generated references with synthetic content, not tested UI.

At accessibility Dynamic Type sizes, the decorative horizon yields to a compact navy brand header; the protection button wraps on a solid surface and chrome margins narrow. Native Reduce Transparency fallback is implemented by `HarborGlass`.

The native review accepted the structure and Horizon fidelity and identified two contrast corrections. The address prompt and first-run supporting body now use primary at 72% opacity; the reviewer confirmed both contrast corrections resolved and issued a scoped ship verdict. The earlier transparent browser surround and centered tab-count changes received a scoped review after simulator geometry assertions, media/fullscreen/restoration regression tests and native screenshot inspection. The reserved solid strip and manual chevron implementation passed four targeted simulator tests and received a scoped finish verdict, but the user subsequently rejected its solid bar and supplied a Safari reference. That direction and acceptance are superseded by the current glass-over-content implementation, which minimizes on scroll into a centered URL pill. Three targeted simulator tests and a repeated dark-appearance test passed. The independent finish reviewer inspected the user references and seven current captures and issued a scoped ship verdict. This record does not claim global visual approval. The implemented tokens and component conventions are in `DESIGN.md`; build/test evidence and physical-device/site limits are in `docs/VALIDATION.md`. Preserve the selected identity in future work.

## Direction contract — collapsible browser controls

THESIS: Keep website content visible behind native glass controls; minimize the controls while scrolling down and restore them by tapping the compact URL.

OWN-WORLD: Preserve Harbor's native glass capsules, semantic content surfaces, SF Symbols and accessible touch targets. The outer browser surround stays transparent; Reduce Transparency applies to the capsules.

STORY: Open with two rows, scroll down a website to minimize them into a centered URL pill, then tap that pill to restore the address and action rows. The compact pill identifies the current site and retains a minimum 44pt touch target.

FIRST VIEWPORT: Existing address and action controls start expanded over content. The website respects the top safe area and extends behind the bottom controls. Measured scroll insets keep ordinary page-end content reachable; fixed CSS footer clearance is not guaranteed by this overlay. Loading progress overlays the address capsule without changing its height.

FORM: Narrow refinement of the incumbent Operate surface, implemented directly; no concept seed or replacement visual world. The user's Safari screenshot and explicit glass-over-content request supersede the reserved solid strip and manual side-chevron direction. There are no manual collapse or expand chevrons; the centered URL pill restores the controls.

FINISH: Targeted simulator verification and independent visual review completed with a scoped ship verdict; documentation reflects the final implementation. Unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.
