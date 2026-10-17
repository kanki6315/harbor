# Harbor website

Scope: a small public app overview and readable privacy policy, hosted on Cloudflare Pages at harbor.arjunakankipati.com. Modes: Persuade and Read. User pinned the existing app identity and supplied the policy; developer is Arjuna Kankipati, contact harbor@arjunakankipati.com. App Store listing: https://apps.apple.com/us/app/harbor-browser/id6819943453.

## Direction contract

THESIS: A quiet Harbor welcome, followed by practical product information and the complete policy.

OWN-WORLD: Inherit Harbor Navy, Wave, Sun, original arch/sun/water SVG geometry, Inter brand typography and rounded content transitions. Stable reading surfaces, capsule navigation; no invented app screenshots.

STORY: Identify Harbor as an iPhone browser, explain continuity, profiles and tracking controls, and make its privacy terms and contact easy to find.

FIRST VIEWPORT: A navy masthead and generously spaced, centered original mark above the app's “An open place to return to.” line. A short browser description and direct policy link lead into a light content surface. Mobile preserves this reading order.

FORM: A compact brand welcome with a three-row feature index, plus a separate policy reading page. Direct implementation of the user's pinned app identity; no random seed or alternative visual world.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Verified web implementation

Reviewed October 7, 2026 against `site/public/styles.css`, both page sources, and the desktop, mobile, and dark screenshots for the overview and policy in `.impeccable/review/`. Visual disposition: ship the static artifact; Cloudflare publication and the custom domain remain unverified.

The website inherits Navy (#0D2747), Blue (#2F8CE6), Wave (#7CC3F3), and Sun (#FFDFA6). Its web reading roles are paper #F5F8FC, ink #0D2747, muted #465A70, rule #D2DEEA, and link #185DA2. Dark mode uses paper #101F30, ink #EDF3FA, muted #B6C8DB, rule #34465B, and link #8BC9F8. These are website-specific CSS adaptations of the native semantic-content principle, not replacements for UIKit adaptive colors.

The bundled Inter variable font supplies the brand and editorial headings, with weight 600 for page headings and 700 for the wordmark. Functional copy uses the system sans stack at 1.0625rem and 1.65 line height. The hero heading scales from 2.5rem to 4.6rem with 1.08 line height and -0.04em tracking; the policy title scales from 2rem to 3.5rem. Policy reading width is capped at 72ch; the general content container at 68rem. At 700px and below, the two-column overview becomes a single column. The content transition retains 26px top corners, and the policy call to action has a 48px minimum height and capsule shape. Navigation and long contact text can wrap when text is enlarged.

Compared with the incumbent native system, the site preserves the supplied mark geometry, maritime palette, Inter branding, rounded content transition, and stable readable surfaces. Editorial Inter headings extend the brand to a public reading surface; native working controls continue to use system type. The site is flat, with no simulated Liquid Glass or decorative shadows. It uses underlined links, explicit focus outlines, themed text selection, and reduced-motion support for anchor scrolling. The original SVG layers and bundled font are the asset sources; no generated raster ships.

`DESIGN.md` and `.impeccable/design.json` remain the native app authority and are unchanged by this web extension. Deployment instructions and outstanding publication checks are in `site/README.md`. The hero pairs Apple's unmodified black "Download on the App Store" badge (48px tall) with the policy pill, below the main message, as the page's only App Store badge.
