---
name: Harbor
description: A calm, persistent iOS browser with Harbor identity and native Liquid Glass controls.
---

<!-- SEED: established with the user before implementation; re-run /impeccable document once there's code to capture the actual tokens and components. -->

# Harbor design system

## Overview

Harbor combines a calm maritime identity with native iOS behavior. The selected visual reference is the Horizon concept: deep blue water, reflected warm sunlight, a clear Harbor mark, and readable content beneath floating Liquid Glass controls. Collections supplies the planned organization model for larger tab sessions. The detailed screen sequence belongs in [the browser surface brief](design/BROWSER-SURFACE.md).

This is a pre-implementation design commitment, not a record of shipped components. The user requested that the direction be saved before writing app code. Exact measurements, accessible color variants and native material rendering remain to be verified during implementation.

Brand authority is [the supplied identity board](design/brand/harbor-identity.png). Use the existing artwork in `assets/HarborIcon/` for the mark; generated concept logos do not replace those assets. Icon Composer source is `assets/HarborIcon/Harbor.icon/`, with separate arch, sun and water SVG layers and light/default and dark previews.

## Colors

The supplied brand palette is authoritative:

| Color | Value | Role |
| --- | --- | --- |
| Harbor Navy | #0D2747 | Brand foundation, dark branded backgrounds, strong text on light surfaces |
| Harbor Blue | #2F8CE6 | Brand action and selection accent; adapt accessible foreground variants as needed |
| Wave | #7CC3F3 | Water highlights and supporting brand artwork |
| Mist | #E8F0F8 | Light app-owned surfaces |
| Sun | #FFDFA6 | Small warm artwork accent, not security status |
| Slate | #1E293B | Supporting dark surfaces and neutral brand text |

These are brand primitives, not a promise that every pairing passes text contrast. Use native semantic label, background and separator colors for functional UI, with tested brand tint variants. Adapt to both appearances and Increase Contrast. Do not use low-contrast blue or Sun for small text on light backgrounds.

Website colors belong to the website. Branded artwork and palettes apply to Harbor-owned surfaces, never injected into arbitrary pages.

## Typography

Inter is the supplied brand face for the Harbor wordmark and intentional brand moments. Use native system typography for navigation, page titles, fields, list rows and settings. SF Symbols supplies interface icons.

Use Dynamic Type text styles rather than fixed point sizes. Preserve a clear hierarchy between page title, domain and supplementary metadata. Long titles wrap or truncate deliberately; full information remains accessible. Exact size and weight tokens are unresolved until native implementation. Do not treat lettering in generated comps as font metrics.

## Layout

Prioritize content, thumb-reachable browsing controls and efficient retrieval from 40+ tabs. Preserve iOS safe areas and native navigation, sheet dismissal and back gestures. Provide at least 44pt hit areas for controls.

Separate dense collections from open branded moments. Large background artwork is appropriate on the start page, not a mandatory header for history, settings or every sheet. Content can scroll beneath floating navigation, with native edge treatment preserving legibility.

At accessibility text sizes, collapse preview grids to readable rows. Reduce or scroll decorative start-page space before compressing useful content. iPhone is the initial target; future iPad layouts require a separate adaptation. Spacing, radii and breakpoints are not fixed by the concept image.

## Elevation & Depth

Use Apple's native Liquid Glass for floating controls and navigation. Let the system provide refraction, highlights, adaptive contrast and material behavior. Standard content surfaces, preview images and list rows stay visually stable and readable.

Avoid nested glass layers and decorative blur on every card. Respect Reduce Transparency and Increase Contrast with appropriately opaque, legible system treatments. Use native motion for navigation and sheets; selected previews may transition into browsing without elaborate choreography. Reduce Motion receives a restrained transition.

Reference: [Apple — Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).

## Shapes

The arch, sun and horizontal water reflections define the brand mark. They are not custom shapes for buttons or navigation. Functional controls use native capsules, circles and rounded surfaces where appropriate. Preview containers use consistent gentle corners; exact radii remain implementation decisions.

Horizon imagery is a start-page asset, not a screen-sized raster containing interface text or controls. Produce it separately from the comp when implementation begins. Use existing vector logo sources rather than tracing generated mockup pixels.

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
- Don't start app implementation as part of this documentation task.
