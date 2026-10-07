# Harbor browser surface

Status: selected direction saved before implementation. Mode: Operate.

## Decision and evidence

The user said, “I like harbor too. Let's save that and update any design documentation around it before we make any code itself,” following the recommendation of Horizon's start page with Collections' tab organization. This record interprets that as acceptance of that recommended direction. Harbor is the app name; Horizon and Collections are concept labels, not product names.

- Primary visual reference: [Horizon](../.impeccable/mocks/harbor-glass/horizon.png).
- Organization reference: [Collections](../.impeccable/mocks/harbor-glass/collections.png).
- Brand source: [Harbor identity](brand/harbor-identity.png).
- Global design authority: [DESIGN.md](../DESIGN.md).

The combined direction is selected; no merged screen comp exists yet. Collections is an organization reference, not approval of every pictured toolbar. Current remains an unselected alternative. No app code, Xcode project or runnable prototype is part of this task.

## First viewport

The start page opens with Harbor's blue horizon and warm reflected sunlight, the Harbor mark and wordmark, followed by a useful Continue Browsing item and real user favorites. Keep the bottom search/address entry reachable. The scenic area establishes identity but must yield space to content at smaller sizes and larger text settings.

Empty state: omit the resume card if no page can be resumed; show a brief invitation to search. Never seed mock favorites as though the user created them. First launch opens this start page; later launches restore the selected browsing tab when session restoration is enabled.

## Task sequence

Launch or restore → enter a domain/search or resume → browse → switch/search open tabs → return to the selected page. The tab switcher is a task surface, not the start page presented on every app launch.

MVP uses All Tabs with local title/domain search, recognizable previews, titles, domains and an unmistakable selected state. Search is prominent enough to make 40+ tabs manageable. Use readable rows at large text sizes. A tab may be selected without reordering the collection. Close supports Undo; closing the final tab opens the start page.

Future groups use Collections' overview and compact in-group previews. Groups are optional, with All Tabs always available. A group count must describe its scope; distinguish “18 in Everyday” from “42 total.” Moving between groups must not require closing tabs. Group deletion must distinguish keeping from closing member tabs.

## Controls and privacy

Use native bottom address/search and action controls in Liquid Glass. Include back, forward, reload/stop, new tab, tab switcher, share and more actions. Exact grouping must fit accessible targets; the generated toolbar is not a complete functional specification. Prefer moving secondary actions to a native menu over crowding the toolbar.

An unobtrusive shield opens protection status and per-site controls. Label it “Tracker blocking on,” “Off for this site,” or an honest unavailable/global-off state. No blocked-request counter unless it can be measured reliably. Site-data clearing explains possible sign-out. Disabling protection offers an explicit reload rather than silently discarding page input.

## Motion and material

Native transitions connect preview selection and browsing. Glass belongs in navigation and control surfaces, with opaque content below. Keep the water artwork still initially; no ambient animation is required. Reduce Motion and Reduce Transparency must work without losing meaning or functionality.

## Boundaries and unresolved details

Tab groups are future scope; the selected design does not authorize implementing them now. Voice input, default favorites, precise toolbar arrangement and detailed group-management flows remain undecided. Light/dark and accessibility variants require native verification. The comps are image-generated references with synthetic content, not tested UI.

Before implementation, reconcile the combined screen composition and resolve practical control placement against the functional brief. Preserve the selected identity; do not restart the design-language exploration. Derive real SwiftUI tokens and component documentation only once implementation exists.
