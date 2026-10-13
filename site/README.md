# Harbor website

Dependency-free static site for https://harbor.arjunakankipati.com. All deployable files are in `public/`; no JavaScript, cookies, external fonts, or analytics are included. The privacy policy describes the iPhone app, not Cloudflare's hosting infrastructure.

## Preview

From the repository root:

```sh
python3 -m http.server 8080 --directory site/public
```

Open http://localhost:8080. The support page is at `/support/` and the policy is at `/privacy/`.

## Deploy to Cloudflare Pages

Create a Pages project in **Workers & Pages** using this Git repository:

- Framework preset: **None**
- Root directory: `site`
- Build command: `exit 0`
- Build output directory: `public`

Alternatively, use Cloudflare Pages Direct Upload and upload the contents of `site/public` (with `index.html` at the upload root). Do not upload the whole iOS repository.

After deploying, open the Pages project's **Custom domains**, choose **Set up a custom domain**, and add `harbor.arjunakankipati.com`. If the zone is on Cloudflare, let the setup create the DNS record. If DNS is elsewhere, add a `harbor` CNAME pointing to the assigned `<project>.pages.dev` hostname after adding the domain to Pages. Wait for the custom domain and HTTPS to become active.

Cloudflare references: [Static HTML](https://developers.cloudflare.com/pages/framework-guides/deploy-anything/), [Custom domains](https://developers.cloudflare.com/pages/configuration/custom-domains/).

## Publication checklist

The supplied policy uses Arjuna Kankipati and harbor@arjunakankipati.com. The confirmed effective date is October 7, 2026. Downloaded Apple crash reports are retained for 7 days after download. Google Workspace processes support email, and support correspondence (including attachments) is deleted every 30 days. Confirm the support mailbox receives mail. No App Store download link is shown because one has not been supplied.

Use `https://harbor.arjunakankipati.com/support/` as the App Store Connect Support URL. Its how-to answers quote the app's labels and navigation as of 0.1.18; update them when Settings or menu wording changes.

Check `/`, `/support/`, `/privacy/`, an unknown path (404), and the Contact link on the deployed custom domain. Cloudflare applies `_headers` at deployment; Python's preview server does not.

## Verification

Checked both pages in Chrome at desktop (1440px) and mobile (390px) widths, in light mode and mobile dark mode. No horizontal overflow or browser errors were observed. The policy also fits a 320px viewport with 200% root text sizing. Local asset and page links resolve, and all supplied policy placeholders are filled. Cloudflare response headers, custom-domain DNS, HTTPS, and mailbox delivery require verification after deployment.

## Brand assets

The SVG mark combines the original Harbor Arch, Sun, and Water SVG layers from `assets/HarborIcon/Harbor.icon/Assets` without changing their path geometry. The favicon adds a navy background. InterVariable and its license are copied from `Harbor/Resources`. No generated imagery is used.

## Cloudflare email handling

Keep the `<!--email_off-->` comments around support email links. These exempt the links from Cloudflare Email Address Obfuscation, whose injected decoder script is blocked by this static site’s Content Security Policy. The public contact address must remain readable and clickable without JavaScript.
