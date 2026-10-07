# History surface

History extends Harbor's native library UI. The selected direction is **Operate**: make real visits easier to find, scan and remove while retaining the searchable SwiftUI List. The system authority remains `DESIGN.md`; this surface introduces no brand tokens or alternate visual identity.

## Find and reopen

Search matches page titles and full addresses, ignoring case and surrounding whitespace. Results retain reverse chronological order, grouped by local calendar day. Section headings use Today, Yesterday or a formatted date; older years include the year. Tapping a visit while browsing opens its address and dismisses History.

The native search field stays in the navigation drawer, with the navigation toolbar visible during search. Empty history and no matching results use distinct native ContentUnavailableView messages. Displayed visits come from the browser archive; this surface supplies no sample content.

## Read a visit

Each row gives the page title primary emphasis, with the domain and local visit time in secondary system typography. A missing or whitespace-only title falls back to the domain or address. Ordinary sizes allow two title lines and place the time beside the domain. Accessibility Dynamic Type removes the title line limit and stacks domain and time. Rows retain a minimum 44pt content height and combine their text for accessibility reading.

Rows use the user's requested compact spacing: a 3pt gap between title and metadata, explicit 6pt top and bottom List row insets, and no additional vertical padding inside the row content. The 44pt minimum content height remains in place.

The inset grouped List, semantic colors and native navigation follow the incumbent library system. Day headings and stronger title hierarchy are surface refinements; Harbor scenery, decorative cards and custom glass are unnecessary in the visit list.

## Manage visits

Select enters native list selection and dismisses the search keyboard. Selected rows do not open pages. Select All applies to the currently displayed search results; changing the search clears the selection. Cancel exits selection and clears it. The selected count appears in the destructive action, which stays disabled until at least one visit is selected. Batch removal requires confirmation and returns to ordinary browsing.

Individual swipe deletion remains available outside selection mode. Clear All remains a separately confirmed action affecting the complete history, including entries hidden by search. Both confirmation messages explain that website logins and tabs are kept. Removal updates the archive and saves it locally.

## Evidence and limits

Behavior and visual roles are recorded from `Harbor/Views/LibraryViews.swift`. They fit the native searchable Lists, semantic content surfaces, system functional typography, Dynamic Type and explicit destructive actions established in `DESIGN.md` and `PRODUCT.md`.

The compact implementation passed iPhone search/clear, filtered-deletion persistence/reopen and accessibility-text checks, plus iPad search/clear checks. Final dark-mode phone, accessibility-text and tablet captures are stored under `.impeccable/review/history/`. Light mode was inspected before the final row-density adjustment. Landscape, physical-device and VoiceOver verification remain outstanding. Xcode emitted a native toolbar-hosting warning; a stalled result-packaging run was replaced by successful screenshot runs with diagnostic collection disabled.
