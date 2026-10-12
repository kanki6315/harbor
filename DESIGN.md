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

Harbor combines a calm maritime identity with native iOS behavior. Deep blue water, reflected warm sunlight and the supplied Harbor mark establish the start page and locked profile screen; semantic content surfaces and native Liquid Glass keep everyday browsing clear. Collections informs tab organization within the same Horizon identity; optional named tab groups now extend the native tab switcher.

This is the implemented SwiftUI system, extracted from `Harbor/Views/HarborTheme.swift`, `StartPage.swift`, `BrowserView.swift`, `TabSwitcherView.swift`, `LibraryViews.swift` and `ProfilesView.swift`. The [identity board](design/brand/harbor-identity.png) remains brand authority. The Xcode project references `assets/HarborIcon/Harbor.icon` directly; the in-app mark draws the supplied SVG path geometry in a resolution-independent Canvas. Generated comp marks never replace the supplied identity. Surface behavior belongs in [the browser brief](design/BROWSER-SURFACE.md).

**Key Characteristics:**
- Still Horizon artwork at the start of browsing and while a profile is locked.
- Native semantic content and glass controls.
- Inter branding with system functional typography.
- Honest personal content and accessible reflow.

## Colors

The implemented reusable brand colors in the frontmatter come from `HarborTheme.swift`. Harbor Navy anchors artwork and placeholder previews; Harbor Blue and Wave provide sea and reflection color; Harbor Sun supplies the small warm artwork accent. Functional tint uses the native accent color except for browser controls, which use semantic primary tint; the page-loading progress indicator specifically uses Harbor Blue.

### Primary

Harbor Navy and Harbor Blue define the maritime artwork. Website content retains its own colors.

### Secondary

Wave and Sun support water, sky and reflected sunlight. Sun is never a security status.

### Neutral

Functional UI uses `Color.primary`, `.secondary`, and UIKit `systemBackground`, `systemGroupedBackground`, `secondarySystemBackground` and `tertiarySystemGroupedBackground`. These are native adaptive roles, not fixed CSS colors. The address prompt, first-run supporting body and locked-profile explanation use primary at 72% opacity. White is used for brand lettering and labels on navy imagery. Mist and Slate remain supplied identity-board colors, but are not extracted as reusable implementation tokens because these SwiftUI surfaces use semantic backgrounds instead.

**The Semantic Content Rule.** Use native adaptive colors for readable functional content; keep the scenery palette in Harbor-owned artwork and deliberate brand moments.

## Typography

**Display Font:** InterVariable, bundled and registered by `HarborApp`, bold and scaled relative to `.largeTitle` for the Harbor wordmark.
**Body Font:** Native system typography through SwiftUI text styles.
**Icons:** SF Symbols, with accessible labels for icon-only actions.

The functional hierarchy uses `.title2.bold()` for first-run and locked-profile headings; `.title3.bold()` for start-page sections; `.headline` for resume titles; `.body` for explanatory text; `.subheadline` for domains, protection labels and tab titles; `.caption` for small metadata; `.caption2.weight(.medium)` for the minimized host pill; and `.caption2.bold()` with monospaced digits for the visible tab count. Native navigation titles, forms and lists retain their platform typography. Do not freeze these roles into fixed point-size tokens.

**The Brand Type Rule.** Reserve Inter for Harbor branding; use Dynamic Type system styles for working controls and content. Toolbar symbols and the compact profile shortcut are capped at `.xxxLarge`; the icon-only profile shortcut retains the full profile name in its accessible label.

## Layout

The browser content occupies a ZStack with native glass controls floating over the page at the bottom. Website views respect the top safe area and extend behind the bottom controls and home-indicator area. A measured bottom scroll inset follows the controls and bottom safe area so ordinary page-end content can scroll above them; fixed CSS footers can still overlap the overlay. The outer control surround is transparent. Start-page scrolling is unclipped beneath the controls, and its background extends through the vertical safe areas. Reduce Transparency supplies opaque capsule backgrounds without adding a solid outer bar. Horizontal chrome insets change from 12pt to 8pt at accessibility Dynamic Type sizes. Button hit areas are at least 44pt, with browser actions and address controls 48pt high. Native media fullscreen hides the browser controls and removes their scroll inset.

The standard start page uses a 350pt artwork region. Its content panel overlaps the artwork by 16pt, uses the page inset token and section spacing, and scrolls. At accessibility sizes the scenery is replaced with a navy brand header and a wrapping protection control; useful content stays below in the scroll view. The mark changes from 94pt to 60pt.

The locked profile screen repeats the start page’s artwork height, mark sizes, overlapping panel and scroll structure. At accessibility sizes it uses the compact navy wordmark header. Profile names, explanatory text, authentication labels and errors wrap vertically; actions remain in the scroll view.

Tab search uses a native navigation drawer. The tab grid uses two columns normally and one column at accessibility sizes, 20pt vertical spacing and 16pt outer padding. Previews reduce from 205pt to 130pt tall at accessibility sizes, leaving readable title/domain information beneath. This is the actual single-column card reflow, not a separate list-row implementation. iPad remains future adaptation.

## Elevation & Depth

`HarborGlass` applies native `.glassEffect(.regular, in: .capsule)` to floating address/action controls and the standard start-page protection button. Reduce Transparency switches that modifier to an opaque `secondarySystemBackground` capsule. Tab close buttons use native regular material in a circle. Native sheets, menus and navigation own their transitions; no custom shadow scale exists. Browser controls share a native `GlassEffectContainer` and address glass identity so the expanded address capsule morphs into the compact URL pill. Address-specific glass uses untinted native regular material in both appearances so iOS manages Liquid Glass preferences; Reduce Transparency retains an opaque `secondarySystemBackground` capsule. Collapse uses a spring response of 0.34 seconds and expansion 0.42 seconds, both with 0.86 damping. Neighboring action controls scale from 0.7 at their bottom edge and fade; address editing uses a 0.38-second spring with the same damping. Reduce Motion uses a 120ms ease-out opacity transition, without the shared-glass morph or action scaling. These timings belong to this control transition, not a global motion scale.

**The Native Material Rule.** Keep glass in the control layer and content on stable semantic surfaces. Do not replace native material behavior with fixed blur/shadow recipes. Horizon artwork is still; there is no ambient animation to disable.

## Shapes

Content cards and previews share the content radius; the start-page and locked-profile panels round only their top corners using the start-panel radius. Capsules belong to floating controls and the native prominent unlock button and circles to tab-close affordances. Selected tab previews have a 4pt accent stroke plus a checkmark, so selection is not communicated by color alone. The arch, sun and reflections define the brand mark, not custom button shapes.

## Components

### Browser controls

One bottom row places Back, a flexible address capsule, tab count and Browser menu over content. There is no top control overlay. Each flanking action has a separate 44pt-wide glass target; the address and action controls use the heights in the frontmatter. The address capsule contains a 44pt-wide profile shortcut, native TextField and contextual reload/stop action at standard text sizes. The shortcut shows only the profile icon, preserves the full profile name in its accessible label, and opens a compact Switch profile sheet with a current-profile checkmark and a Profile settings link that opens Settings → Profiles. At accessibility Dynamic Type sizes reload/stop remains available in Browser menu, leaving more room for the field. Site protection is available in Browser menu at every text size. Controls use semantic primary tint with untinted, system-managed regular glass. Editing gives the address field the full row width with a Go action and hides the profile shortcut and flanking controls. Loading progress overlays the address capsule without changing its height.

Scrolling down a website minimizes the row into a centered host-only glass pill. Its small `.caption2` label is capped at `.xxxLarge`, truncates in the middle and has a maximum width of 112pt normally or 180pt at accessibility text sizes. The visible capsule retains a minimum 44pt hit area extending upward. It lowers toward the home indicator by `min(12, max(0, bottomInset - 20))` points, preserving clearance on smaller safe areas. Its accessible name includes the site and current profile. Tapping restores the row without focusing the address field; switching tabs also restores the row.

The tab count is centered inside a 24pt rounded outline (5pt corner radius, 1.8pt stroke), with horizontal text padding and a 0.5 minimum scale factor for larger counts; its accessibility label reads the full count. Disabled navigation uses native disabled state. Browser menu contains Share page when a URL exists, Bookmarks, History, New tab, Forward, reload/stop, Site protection, Settings, and available media/download actions. Profiles also remains reachable from Settings. Bookmarks provides a labeled action to save or remove the current page. System sheets and UIActivityViewController handle modal tasks and sharing.

### Start-page content

A resume card shows the most recent real history entry. The honest first-run alternative is “Where to next?” with a search action. Favorites show up to six real bookmarks; recently visited shows up to four further history entries. These sections do not create demonstration data. Titles/domains have deliberate line limits; cards use semantic grouped backgrounds and plain button interaction.

### Locked profile

Keep the lock experience in the same visual world as the start page: shared `HorizonArtwork`, supplied `HarborMark`, Inter wordmark and tagline above the adaptive grouped content panel. The profile name appears with a lock symbol and a heading accessibility trait. The explanatory body stays on a stable semantic surface.

The primary action uses native `.borderedProminent` styling with a capsule border shape and a full-width label with a minimum 44pt height. Its label names the available authentication method. A native progress indicator appears during authentication and both unlock and switch-profile actions disable until it finishes. Switch profile is the secondary text action and opens the native Profiles sheet. Authentication errors appear below the actions with an exclamation symbol and wrapping body text.

The actual profile lock state selects this screen in place of the browser and its presented sheets. An inactive but unlocked scene retains its browser preview; protected profiles lock on return after their configured time away (30 minutes by default). The native profile editor’s “Lock after” picker offers Immediately, 1, 5, 15 or 30 minutes, and 1 hour. Switching profiles and restarting Harbor still require authentication. The lock screen exposes no tab previews or browsing content.

### Tab cards

Use actual captured snapshots when present, otherwise a navy placeholder with the Harbor mark for a start page or a globe/domain for a website. Separate close and open targets preserve intent. Cards support drag reordering, accessible move actions and a native Reorder list. Successful local snapshots persist across launches and background-tab unloading; unloaded pages restore their history and scroll position when selected. Selected state combines border and checkmark; playing media adds a labeled speaker symbol. Closing exposes native toolbar Undo close.

### Library, settings and privacy

History and bookmarks use native searchable Lists, swipe deletion and ContentUnavailableView empty states. Bookmarks provides named folders with native drill-down navigation, an Unfiled section, and swipe/context actions for rename, move and delete. Folder deletion preserves saved pages in Unfiled. New bookmarks save immediately with the page title. Inline suggestion feedback shows a spinner and “Suggesting a name…”, then the proposed name with Use name and Keep original. No suggestion is applied automatically. A native rename Form offers Suggest nickname, an editable field and explicit Save/Cancel; accepting a suggestion there only fills the draft. Failure feedback keeps the name unchanged and can be dismissed. Manual saves, rejection and profile deactivation cancel outstanding generation. Root bookmark search spans all folders. History uses inset grouped day sections, medium-weight body titles, secondary domain/time metadata and native selection controls. At accessibility sizes, titles wrap without a line limit and domain/time metadata stacks vertically. Search stays visible alongside the toolbar; selection supports deleting chosen visits, while Clear All uses a separate confirmation. Empty history and no search matches have distinct messages. Settings and Privacy use native Forms, sections, toggles, pickers and confirmation dialogs. Destructive data clearing describes its effects. Per-site protection changes offer an explicit reload, and never show an invented blocked-request count.

## Do's and Don'ts

- Do preserve the Harbor mark and supplied palette.
- Do keep glass in the control/navigation layer and content legible beneath it.
- Do make selection and protection states understandable without color alone.
- Do keep locked profiles visually consistent with Harbor while withholding browsing content.
- Do support light mode, dark mode, Dynamic Type and accessibility appearance settings.
- Do keep privacy language factual: tracker blocking does not mean incognito or complete anonymity.
- Don't copy generated sample sites, favorites or counts into real user data.
- Don't add inactive group controls before groups exist.
- Don't carry mockup microphone icons into scope without an explicit voice-input decision.
- Don't invent fixed blur, shadow or layout tokens from an illustration.
