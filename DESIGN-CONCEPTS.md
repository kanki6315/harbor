# Harbor: three browser concepts

Status: superseded exploration. The user found these directions too similar and supplied a Harbor identity board. Active exploration: `design/HARBOR-GLASS-CONCEPTS.md`. These remain historical generated visual comps, not running iOS screenshots. No concept here was approved for implementation.

## Shared behavior

Design for 40+ persistent tabs. Finding an existing page is as important as opening a new one. The browser uses native navigation, system text styles, SF Symbols, semantic light/dark colors, and accessible hit areas. The webpage owns its own appearance; browser theming never silently recolors sites.

- Bottom address field: shield, readable domain, reload/stop. Editing reveals the full URL and keyboard; submitting a domain opens it, other text searches. Cancel returns to the page without navigation.
- Browsing toolbar: back, forward, share, tab count, more. Tab switcher has a prominent new-tab action. More includes New Tab, Bookmarks, History, and Settings.
- Tab search is local, across titles and URLs. Opening it does not send queries to a search engine. When groups exist, offer All Tabs search and show each result's group.
- Preserve a predictable tab order; do not reorder the grid/list on every selection. Return the switcher to the selected tab. Closing a tab offers Undo; closing the last tab opens the start page. Group deletion must distinguish keeping tabs from closing them.
- A shield sheet names the current site and shows blocking status and a per-site control. No invented blocked-request count. Global-off state explains why the site control is inactive. A proposed reload after changing protection is explicit so unsaved page input is not silently discarded.
- Clear Website Data is separate from history deletion, with a confirmation explaining possible sign-out. Bookmark removal and tab closure do not delete website sessions.
- At accessibility text sizes, preview layouts become readable single-column rows; labels wrap and controls remain accessible. State never relies on color alone. Support Reduce Motion.

## Index

Warm ivory, ink text, oxblood tint; SF typography with deliberate title/domain hierarchy. Inspired by a book index's scanning rhythm, expressed through native list rows rather than literal paper styling.

The tab switcher is a compact searchable list. Each row carries favicon, title, domain, selected indicator, and close action. This maximizes useful names on screen. A native scope menu leaves room for groups without forcing them into the MVP.

Signature: consistent title/domain alignment makes a large session easy to scan. Bookmarks and history share that same rhythm; settings remain native grouped lists. Light appearance shown; dark counterpart uses warm charcoal, pale labels and an accessible lighter tint.

Tradeoff: titles are efficient when distinctive, but similar titles are harder to distinguish without page previews.

## Cove

Cool pale blue-gray chrome, ink-blue text, ocean teal tint. Inspired by calm wayfinding: clear landmarks, strong selection, generous separation, no literal maritime decoration.

The tab switcher is a two-column preview grid with search above it. The selected preview has a thin tint outline and a check. Title and domain stay visible below each image. Navigation, new-tab page, bookmarks and settings share the quiet spacing and tint.

Signature: the page preview becomes the visual return point to browsing, using a restrained native transition and a Reduce Motion alternative. Dark counterpart uses cool charcoal rather than bright tinted backgrounds.

Tradeoff: highly familiar and easy to recognize, but 40+ tabs require more scrolling. Search must stay easy to reach. Preview generation and memory use need implementation limits.

## Slate

Graphite/navy chrome, off-white labels, periwinkle tint, hairline separators. Compact preview rows combine image recognition with readable titles. Native controls stay familiar; no console styling or artificial glow.

The comp previews a future state: collapsible groups Everyday (18), Research (14), Weekend (10), totaling 42. All-tabs search sits above group scope. MVP can use the same rows under All Tabs before groups exist.

Signature: collapse a group to regain an overview without closing its tabs. History and bookmarks inherit the compact row language. Light counterpart uses slate-white surfaces with deep blue interactive tint.

Tradeoff: strongest organization for long-lived sessions, but groups introduce management work. Do not require groups, automatically classify tabs, or ship dormant controls in the MVP.

## Common state coverage for implementation

Empty start page: search entry and explanatory empty sections without fake bookmarks. Loading: real navigation progress and Stop. Failed navigation: retain address and offer Retry. Failed blocker setup: honest unavailable status, never a protected badge. No tab-search results: retain query and offer Clear Search. Very long titles/domains: wrapping or truncation with full accessible labels. Closing active tab: deterministic neighboring selection. Restored tabs: title/domain immediately available while selected content loads; avoid eager restoration of 40 webviews.

## Review decision

Choose a visual language and tab browsing pattern, or combine named aspects. Palette is not the only choice: Index prioritizes text scanning, Cove image recognition, Slate grouping and density. Group concepts are future-facing and do not expand the confirmed first milestone.

The comps contain synthetic webpage content and only demonstrate the intended hierarchy. Native accessibility, typography, toolbar behavior, exact hit targets, both appearances, and WebKit behavior require implementation and device verification.

Generated with the built-in image-generation tool. Exact prompts live beside the images in `.impeccable/mocks/`.
