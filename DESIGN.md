---
name: Harbor
description: A calm, persistent native iOS browser with Horizon artwork and Liquid Glass controls.
colors:
  harbor-navy: "#0D2747"
  harbor-blue: "#2F8CE6"
  harbor-wave: "#7CC3F3"
  harbor-sun: "#FFDFA6"
typography:
  brand:
    fontFamily: "InterVariable"
    fontSize: "34pt"
    fontWeight: 700
rounded:
  content: "18pt"
  start-panel: "26pt"
spacing:
  compact: "8pt"
  section-label: "12pt"
  inset: "16pt"
  card: "18pt"
  page: "24pt"
  section: "26pt"
components:
  resume-card:
    rounded: "{rounded.content}"
    padding: "{spacing.card}"
  address-field:
    height: "48pt"
  toolbar-action:
    height: "48pt"
  tab-preview:
    rounded: "{rounded.content}"
---

# Design System: Harbor

## Overview

**Creative North Star: "Horizon"**

Harbor combines a calm maritime identity with native iOS behavior. Deep blue water, reflected warm sunlight and the supplied Harbor mark establish the start page; semantic content surfaces and native Liquid Glass keep everyday browsing clear. Collections remains a reference for future organization, not a second identity or an implemented groups feature.

This is the implemented SwiftUI system, extracted from `Harbor/Views/HarborTheme.swift`, `StartPage.swift`, `BrowserView.swift` and `TabSwitcherView.swift`. The [identity board](design/brand/harbor-identity.png) remains brand authority. The Xcode project references `assets/HarborIcon/Harbor.icon` directly; the in-app mark draws the supplied SVG path geometry in a resolution-independent Canvas. Generated comp marks never replace the supplied identity. Surface behavior belongs in [the browser brief](design/BROWSER-SURFACE.md).

**Key Characteristics:**
- Still Horizon artwork at the start of browsing.
- Native semantic content and glass controls.
- Inter branding with system functional typography.
- Honest personal content and accessible reflow.

## Colors

The implemented reusable brand colors in the frontmatter come from `HarborTheme.swift`. Harbor Navy anchors artwork and placeholder previews; Harbor Blue and Wave provide sea and reflection color; Harbor Sun supplies the small warm artwork accent. Functional tint uses the native accent color; the page-loading progress indicator specifically uses Harbor Blue.

### Primary

Harbor Navy and Harbor Blue define the maritime artwork. Website content retains its own colors.

### Secondary

Wave and Sun support water, sky and reflected sunlight. Sun is never a security status.

### Neutral

Functional UI uses `Color.primary`, `.secondary`, and UIKit `systemBackground`, `systemGroupedBackground`, `secondarySystemBackground` and `tertiarySystemGroupedBackground`. These are native adaptive roles, not fixed CSS colors. The address prompt and first-run supporting body use primary at 72% opacity after contrast review. White is used for brand lettering and labels on navy imagery. Mist and Slate remain supplied identity-board colors, but are not extracted as reusable implementation tokens because these SwiftUI surfaces use semantic backgrounds instead.

**The Semantic Content Rule.** Use native adaptive colors for readable functional content; keep the scenery palette in Harbor-owned artwork and deliberate brand moments.

## Typography

**Display Font:** InterVariable, bundled and registered by `HarborApp`, bold and scaled relative to `.largeTitle` for the Harbor wordmark.
**Body Font:** Native system typography through SwiftUI text styles.
**Icons:** SF Symbols, with accessible labels for icon-only actions.

The functional hierarchy uses `.title2.bold()` for the first-run heading; `.title3.bold()` for start-page sections; `.headline` for resume titles; `.body` for explanatory text; `.subheadline` for domains, protection labels and tab titles; `.caption` for small metadata; and a compact 12pt bold rounded system face with monospaced digits for the visible tab count. Native navigation titles, forms and lists retain their platform typography. Do not freeze these roles into fixed point-size tokens.

**The Brand Type Rule.** Reserve Inter for Harbor branding; use Dynamic Type system styles for working controls and content. Toolbar symbols are capped at `.xxxLarge` while text and accessible names remain available.

## Layout

The browser content occupies a ZStack with native glass controls floating over the page at the bottom. Website views respect the top safe area and extend behind the bottom controls and home-indicator area. A measured bottom scroll inset follows the controls and bottom safe area so ordinary page-end content can scroll above them; fixed CSS footers can still overlap the overlay. The outer control surround is transparent. Start-page scrolling is unclipped beneath the controls, and its background extends through the vertical safe areas. Reduce Transparency supplies opaque capsule backgrounds without adding a solid outer bar. Horizontal chrome insets change from 16pt to 8pt at accessibility Dynamic Type sizes. Button hit areas are at least 44pt, with browser actions and address controls 48pt high. Native media fullscreen hides the browser controls and removes their scroll inset.

The standard start page uses a 350pt artwork region. Its content panel overlaps the artwork by 16pt, uses the page inset token and section spacing, and scrolls. At accessibility sizes the scenery is replaced with a navy brand header and a wrapping protection control; useful content stays below in the scroll view. The mark changes from 94pt to 60pt.

Tab search uses a native navigation drawer. The tab grid uses two columns normally and one column at accessibility sizes, 20pt vertical spacing and 16pt outer padding. Previews reduce from 205pt to 130pt tall at accessibility sizes, leaving readable title/domain information beneath. This is the actual single-column card reflow, not a separate list-row implementation. iPad remains future adaptation.

## Elevation & Depth

`HarborGlass` applies native `.glassEffect(.regular, in: .capsule)` to floating address/action controls and the standard start-page protection button. Reduce Transparency switches that modifier to an opaque `secondarySystemBackground` capsule. Tab close buttons use native regular material in a circle. Native sheets, menus and navigation own their transitions; no custom shadow scale exists. Browser controls share a native `GlassEffectContainer` and address glass identity so the expanded address capsule morphs into the compact URL pill. Collapse uses a smooth 240ms transition and expansion 320ms, both with zero extra bounce; the action row fades with a 12pt vertical offset. Reduce Motion uses a 120ms ease-out opacity transition, without the shared-glass morph or action-row offset. These timings belong to this control transition, not a global motion scale.

**The Native Material Rule.** Keep glass in the control layer and content on stable semantic surfaces. Do not replace native material behavior with fixed blur/shadow recipes. Horizon artwork is still; there is no ambient animation to disable.

## Shapes

Content cards and previews share the content radius; the start-page panel rounds only its top corners using the start-panel radius. Capsules belong to floating controls and circles to tab-close affordances. Selected tab previews have a 4pt accent stroke plus a checkmark, so selection is not communicated by color alone. The arch, sun and reflections define the brand mark, not custom button shapes.

## Components

### Browser controls

The address capsule combines a shield button, current-profile shortcut, native TextField and contextual Go or reload/stop action. The second capsule contains Back, Forward, New tab, tab count and Bookmarks. Floating top controls with a transparent outer surround place Share, History and Settings in that order at the trailing edge and contextual Page actions at the leading edge. Both capsules start expanded. Scrolling down a website minimizes them into a small centered glass URL pill that shows the site host, truncates long text in the middle and retains a minimum 44pt touch target. The top controls overlay content within the top safe area and collapse with the bottom controls without resizing the website. Tapping the pill restores all controls; switching tabs also restores the expanded controls. Address editing expands the address row and hides the top and bottom action rows. Loading progress overlays the address capsule without changing its height. The tab count is centered inside a 27pt rounded outline (5pt corner radius, 1.8pt stroke), with horizontal text padding and a 0.5 minimum scale factor for larger counts; its accessibility label reads the full count. Disabled navigation uses native disabled state. Share appears when the current tab has a URL. Page actions appears only for available download/media actions. Bookmarks provides a labeled action to save or remove the current page. Settings links to profile management; the address-bar profile shortcut remains available for quick switching. System sheets and UIActivityViewController handle modal tasks and sharing.

### Start-page content

A resume card shows the most recent real history entry. The honest first-run alternative is “Where to next?” with a search action. Favorites show up to six real bookmarks; recently visited shows up to four further history entries. These sections do not create demonstration data. Titles/domains have deliberate line limits; cards use semantic grouped backgrounds and plain button interaction.

### Tab cards

Use actual captured snapshots when present, otherwise a navy placeholder with the Harbor mark for a start page or a globe/domain for a website. Separate close and open targets preserve intent. Cards support drag reordering, accessible move actions and a native Reorder list. Successful local snapshots persist across launches and background-tab unloading; unloaded pages reload when selected. Selected state combines border and checkmark; playing media adds a labeled speaker symbol. Closing exposes native toolbar Undo close.

### Library, settings and privacy

History and bookmarks use native searchable Lists, swipe deletion and ContentUnavailableView empty states. Settings and Privacy use native Forms, sections, toggles, pickers and confirmation dialogs. Destructive data clearing describes its effects. Per-site protection changes offer an explicit reload, and never show an invented blocked-request count.

## Do's and Don'ts

- Do preserve the Harbor mark and supplied palette.
- Do keep glass in the control/navigation layer and content legible beneath it.
- Do make selection and protection states understandable without color alone.
- Do support light mode, dark mode, Dynamic Type and accessibility appearance settings.
- Do keep privacy language factual: tracker blocking does not mean incognito or complete anonymity.
- Don't copy generated sample sites, favorites or counts into real user data.
- Don't add inactive group controls before groups exist.
- Don't carry mockup microphone icons into scope without an explicit voice-input decision.
- Don't invent fixed blur, shadow or layout tokens from an illustration.
