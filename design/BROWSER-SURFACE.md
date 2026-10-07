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

Use native bottom address/search and action controls in Liquid Glass. Include back, forward, reload/stop, new tab, tab switcher, share and more actions. The implemented two-capsule arrangement puts the shield, field and contextual Go/reload/stop in the first row; Back, Forward, New tab, tab count and More in the second. Editing hides the second row. The tab count is centered in a 27pt rounded outline and scales down for larger counts. Website content extends under the vertical safe areas and transparent outer browser chrome; start-page content can also scroll beneath the bars, with its background extended through the safe areas; native glass capsules and their Reduce Transparency fallback remain. Share, bookmark, history, settings and available media/download actions live in More.

An unobtrusive shield opens protection status and per-site controls. Label it “Tracker blocking on,” “Off for this site,” or an honest unavailable/global-off state. No blocked-request counter unless it can be measured reliably. Site-data clearing explains possible sign-out. Disabling protection offers an explicit reload rather than silently discarding page input.

## Motion and material

Native transitions connect preview selection and browsing. Glass belongs in navigation and control surfaces, with opaque content below. Keep the water artwork still initially; no ambient animation is required. Reduce Motion and Reduce Transparency must work without losing meaning or functionality.

## Implementation and verification boundaries

Tab groups are future scope; the selected design does not authorize implementing them now. Voice input and detailed group-management flows remain outside the implementation. There are no seeded favorites. Native light/dark and large-text variants exist; hardware accessibility checks remain in the validation checklist. The comps are image-generated references with synthetic content, not tested UI.

At accessibility Dynamic Type sizes, the decorative horizon yields to a compact navy brand header; the protection button wraps on a solid surface and chrome margins narrow. Native Reduce Transparency fallback is implemented by `HarborGlass`.

The native review accepted the structure and Horizon fidelity and identified two contrast corrections. The address prompt and first-run supporting body now use primary at 72% opacity; the reviewer confirmed both contrast corrections resolved and issued a scoped ship verdict. The later user-requested transparent browser surround and centered tab-count changes are implemented, with simulator geometry assertions, media/fullscreen/restoration regression tests and native screenshot inspection completed; the reviewer accepted these changes within that scope. This record does not claim global visual approval. The implemented tokens and component conventions are in `DESIGN.md`; build/test evidence and physical-device/site limits are in `docs/VALIDATION.md`. Preserve the selected identity in future work.
