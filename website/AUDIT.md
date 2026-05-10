# Clipboard History — Website Audit (baseline)

Working artifact for `website-seo` team. Read-only audit of `website/` as of 2026-05-10.
Format: lane-grouped gaps, each with file:line pointer + suggested owner task.

## Inventory snapshot

- 1 entry HTML (`index.html`, 171 lines), 6 `.jsx` files (≈1,000 lines), 1 `site.css` (1,394 lines, 40 KB).
- Runtime React 18 + Babel 7 from `unpkg.com` — three blocking external scripts in `<head>`, including `babel/standalone` (~700 KB transpiling 6 JSX files at boot).
- `og.png` 232 KB · `clipboard-history-demo.gif` 2.3 MB (unreferenced on page) · `clipboard-history-demo.mp4` 1 MB (unreferenced on page).
- 1 sitemap URL, basic robots.txt, two JSON-LD blocks, full noscript fallback.
- Theme: light/dark via `data-theme`; tweaks panel intentionally left in (host-protocol scaffolding).

## Top 15 gaps

### Meta (→ task #2)
1. **No `<html lang>` switch + missing `<meta name="application-name">`, `<meta name="apple-mobile-web-app-*">`, `<meta name="format-detection" content="telephone=no">`.** Twitter card lacks `twitter:site` / `twitter:creator`; OG missing `og:image:type`. `index.html:1-31`.
2. **Keyword stuffing in `<meta name="keywords">`** (`index.html:11`) — modern crawlers ignore it; better to drop or trim. Description is also ~270 chars (truncates in SERPs at ~155–160).
3. **No real favicon set, no `apple-touch-icon`, no `manifest.webmanifest`, no `<link rel="icon" sizes>`.** Inline SVG only (`index.html:34`) — Safari pinned tabs and iOS home-screen save will be broken.

### Schema (→ task #3)
4. **FAQ JSON-LD doesn't match visible FAQ text verbatim** (e.g. "Is Clipboard History free?" in JSON vs "Is it really free?" rendered — `index.html:81` vs `sections.jsx:128`). Google requires literal match or it disqualifies the rich result. Same drift on Q3 ("Which Macs does it work on?" vs "Which Macs work with it?").
5. **Missing schemas:** `Organization` (logo, sameAs → GitHub), `WebSite` with `SearchAction` (skip if no on-site search — but add `@id` graph), `BreadcrumbList`, `SoftwareApplication.aggregateRating` (only add if real), `screenshot[]` array, `softwareVersion` is hardcoded "1.2" but README ships v0.0.21 (`index.html:52`). `applicationSubCategory: "Clipboard Manager"` would help.

### Perf (→ task #5) — heuristic only, no Lighthouse run
6. **Runtime Babel + 3 blocking unpkg scripts in `<head>`** (`index.html:115-117`) — likely 800 KB+ of JS parsed before first paint and a transpile pass over every `.jsx`. Single biggest LCP / TBT win is a build step (esbuild/vite) emitting one minified bundle, served same-origin.
7. **JSX `<script type="text/babel" src="…">` tags** (`index.html:163-169`) are sequential and un-deferred; demo image `screenshots/03-current.jpg` referenced from React init (`hero.jsx:19`) won't preload. Add `<link rel="preload" as="image">` for hero LCP image (or inline an SVG mock for the hero overlay thumb).
8. **`uploads/clipboard-history-demo.gif` is 2.3 MB and not referenced on the live page**, only in `README.md`. If it's intentional ship `.mp4` (1 MB, already on disk) with `<video autoplay muted loop playsinline>`. Otherwise leave out of `website/` to keep deploy slim. `og.png` 232 KB could be ~60 KB as WebP.

### A11y (→ task #6)
9. **Zero `:focus-visible` styles in the entire stylesheet** (`grep` confirms only `.twk-field:focus` exists, used by the dev-only tweaks panel). Keyboard users get no visible focus ring on any nav link, button, or `<details>` summary. Required for WCAG 2.4.7.
10. **No `prefers-reduced-motion` handling.** Hero overlay rotates every 2.2s (`hero.jsx:9`), search demo every 1.5s (`features.jsx:65`), before/after every 1.8s (`features.jsx:209`) — vestibular trigger. Wrap intervals + CSS transitions with `@media (prefers-reduced-motion: reduce)` overrides.
11. **Decorative-only icons missing `aria-hidden="true"`** — every `<Icon.* />` in feature cards, footer, FAQ etc. is exposed to screen readers as inline SVG. Heading hierarchy is mostly OK (single `h1` in hero, `h2` per section, `h3` in cards) but `<h4>` in privacy points (`sections.jsx:51`) skips no levels — fine.
12. **`<input readOnly>` in hero overlay** (`hero.jsx:27`) is focusable but does nothing — it's a fake. Add `aria-hidden="true"` on the surrounding `.overlay` (it's a screenshot, not a real dialog) or remove `role="dialog"` which is misleading. Same for `tab-pill` buttons inside it.

### Content / Copy (→ tasks #7, #8)
13. **FAQ has only 4 questions, all defensive ("is it free / safe / fast")** (`sections.jsx:127-132`). Missing high-intent queries: "How do I open clipboard history on Mac", "Best clipboard manager Mac 2026", "Difference vs Maccy / Paste / Pastebot / Raycast clipboard", "Does it sync between Macs", "Where is the data stored", "Can I export my clipboard history", "How do I uninstall", "Does it work with iCloud / Universal Clipboard". Each is a real long-tail SEO query — answer them and let `FAQPage` schema pick them up.
14. **No supporting content beyond the landing page.** A site this thin will struggle to rank for "clipboard manager mac". Candidates: `/changelog`, `/privacy`, `/uninstall`, `/vs-maccy` comparison, `/keyboard-shortcuts` deep page (already have data), `/screenshots`. Even one or two would 4–10× internal linking surface and earn long-tail traffic.

### UI / Interactions / Analytics (→ tasks #9, #10, #11)
15. **No social proof, no sticky download CTA on scroll, no analytics, no event tracking.** Missing: GitHub star count badge (server-render or fetch with skeleton), "Featured on…" strip if any, mobile-detection banner ("This is a Mac app — open on your Mac to download"), download click event (privacy-respecting, e.g. Plausible/Umami self-hosted). The download URL is fetched client-side from GitHub API on every page view (`download.jsx:11`) — fine, but cache or fall back gracefully if API rate-limits visitors on shared IPs.

## Cross-cutting notes (not in top 15 but worth flagging)

- `og.png` width/height declared (good) but no `og:image:type` — add `image/png`.
- `<title>` is 51 chars (good), description 268 chars (long — trim to ~155).
- Sitemap lists one URL with `priority 1.0` — once content pages exist, scale priorities and add `lastmod` from git.
- Robots.txt allows everything but doesn't address AI crawlers (GPTBot, ClaudeBot, PerplexityBot, Google-Extended). Decide a stance — task #4 owns this.
- README inside `website/` is 3 lines; team-lead may want to expand or delete to avoid confusion with project root README.
- Hardcoded `softwareVersion: "1.2"` in JSON-LD will rot (project is at v0.0.21). Either drop the field or wire to release tag at build time.
- `data-theme` set to `"light"` in HTML, but App overrides it from localStorage/tweaks → brief flash of light theme for dark-mode users. Add a tiny inline `<script>` in `<head>` to set theme before paint, or honor `prefers-color-scheme` server-side.
- `FAQ` uses native `<details>/<summary>` (`sections.jsx:141`) — good for no-JS, but no animation and no analytics on open.
- The hero `.overlay` thumbnail loads `screenshots/03-current.jpg` (`hero.jsx:19`) which is 33 KB JPEG — fine, but it's the only `<img>` on the page above the fold, so it should be `fetchpriority="high"` and ideally `<picture>` with WebP/AVIF.

## What's already good (don't break)

- Solid noscript fallback with full content + FAQ — search engines see the substance even if JS fails.
- Canonical, OG, Twitter card all present and correct domain.
- Two JSON-LD blocks (`SoftwareApplication`, `FAQPage`).
- Apple-style design language is consistent and clean; `clamp()` typography scales well.
- Brand voice in copy matches README ("Stop losing what you copy", "Most people forget it's running") — keep it.

## Files touched

- Created: `website/AUDIT.md` (this file).
- No source files modified.
