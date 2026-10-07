# Harbor / Liquid Glass exploration

Status: direction selected. Horizon provides the visual identity and start page; Collections provides the future tab-organization model. See `../DESIGN.md` and `BROWSER-SURFACE.md` for the saved decision and implementation boundaries. Current remains an alternative. Generated comps are visual direction studies, not verified native screenshots.

## Authority

The user's Harbor identity board governs all three concepts: navy #0D2747, blue #2F8CE6, wave #7CC3F3, mist #E8F0F8, sun #FFDFA6, slate #1E293B; arch, sun and reflected-water mark; Inter for brand moments. Use system typography and SF Symbols for native controls. Production logo sources now exist in `../assets/HarborIcon/`, including layered SVGs and an Icon Composer document; generated interpretations are references only.

Apple's Liquid Glass guidance places the material in the navigation and control layer, above content. Use native system components and material behavior, with Reduce Transparency, Increase Contrast, Dynamic Type and Reduce Motion respected. These static studies suggest the material; actual refraction, scrolling behavior, contrast and accessibility need simulator/device verification.

Reference: https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass

## Horizon — visual return point

Harbor's horizon and reflected sunlight belong on the app's own start page. A prominent resume card and a few favorites create a calm entry. A preview grid helps recognize tabs. The lower address and action controls float over app content using Liquid Glass.

Distinct structure: open scenic start, one primary resume card, visual tab grid. Best for browsing by recognition. Cost: 40+ tabs still demand good search and later groups; scenic content must stay subordinate to browsing tasks. Website content never inherits the home wallpaper or palette.

## Collections — organize the session

A light Mist library makes groups the main entry point. Collection contact sheets show contents, titles and counts; opening one produces compact thumbnail rows. Tabs, Bookmarks and History are destinations, while New Tab stays a separate action.

Distinct structure: group library first, page second. Best fit when 40+ tabs are deliberately kept by topic. Cost: this direction depends most on tab groups, which remain future scope unless the user elects to prioritize them. In an MVP without groups, show a single All Tabs collection and avoid inactive grouping controls.

## Current — find and resume

Local tab search and recent activity lead a compact navy interface. The normal address entry must distinguish navigation/search-engine submission from local tab matches. A partial-height tab sheet previews quick switching while keeping the current page visible; All Tabs expands into full management.

Distinct structure: text-first find/resume, with an optional contextual switcher. Best for retrieving a specific page from a long session. Cost: keyboard and sheet coordination require care. Large Dynamic Type and keyboard presentation may require a full-height sheet. Never send local tab search text to a search engine without explicit submission.

## Shared requirements

- Stable tab ordering, local title/domain search, explicit active-tab state, Undo Close, and persistent sessions.
- Group counts and content in comps are synthetic examples, not implemented features.
- Protection shield opens site controls; no fabricated blocked counts or absolute anonymity claims.
- Bottom address control remains reachable. Stop/reload state is real, not a decorative spinner.
- Glass controls have accessible labels and 44pt minimum hit areas; glass is not layered onto every content card.
- Dark and light appearances are required for the chosen direction. Each concept's displayed appearance is a composition choice, not a theme restriction.
- Sun yellow is a small brand accent, never low-contrast body text or an ambiguous security indicator.
- Destructive website-data actions explain sign-out consequences. Closing tabs does not clear cookies.

## Deliverables

Three built-in image-generation comps and exact prompt sidecars under `.impeccable/mocks/harbor-glass/`. Brand reference is `design/brand/harbor-identity.png`. The combined Horizon/Collections direction is saved; no merged comp or app implementation exists yet.
