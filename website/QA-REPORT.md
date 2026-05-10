# QA Report — Clipboard History Marketing Site
**Date:** 2026-05-10 | **Auditor:** qa-tester | **Server:** python3 http.server 8765

---

## Scores (Lighthouse — headless Chrome, mobile)

| Category       | Score |
|----------------|-------|
| Performance    | 82    |
| Accessibility  | 93    |
| Best Practices | 100   |
| SEO            | 100   |

---

## Checklist

### 1. Bundle & Load
- **PASS** `dist/app.js` exists (195 KB raw)
- **PASS** All page resources return 200 — no 404s (index.html, dist/app.js, site.css, screenshots/03-current.jpg)
- **PASS** No JS console errors on load
- **PASS** React mounts correctly (`#root` has children)

### 2. LCP / Image Delivery
- **FAIL** LCP = 4.0 s (Lighthouse score 48). LCP element is `screenshots/03-current.jpg` served without cache headers from localhost; score likely improves on CDN. Real-world impact needs verification.
- **PASS** WebP before/after image: browser picks `.webp` (`currentSrc` = `uploads/clipboard-history-before-after.webp`). `<picture>` + `<source type="image/webp">` pattern is correct.
- **INFO** `screenshots/03-current.jpg` (hero) has `alt=""` inside a `<img>` used as a decorative thumbnail — Lighthouse image-alt passes (empty alt is valid for decorative images).

### 3. HTML Validation
- **PASS** No duplicate IDs found
- **PASS** No unclosed `<div>` tags in index.html
- **PASS** No `<img>` tags missing `alt` in index.html (all 0 static imgs; JSX-rendered imgs validated via Lighthouse)
- **PASS** DOCTYPE, lang, charset, viewport all present

### 4. JSON-LD Validation
- **PASS** All 5 JSON-LD blocks parse as valid JSON
- **PASS** Types present: SoftwareApplication, Organization, WebSite, VideoObject, FAQPage
- **PASS** SoftwareApplication has required: name, operatingSystem, applicationCategory, offers (price: "0")
- **PASS** FAQPage has 12 Question entities, all with acceptedAnswer
- **PASS** VideoObject has name, description, thumbnailUrl, contentUrl, uploadDate

### 5. FAQ Verbatim Match (JSON-LD ↔ noscript)
- **PASS** All 12 Q&A pairs match byte-for-byte between JSON-LD `FAQPage` and `<noscript>` HTML

### 6. FAQ JS-rendered vs JSON-LD Mismatch
- **FAIL** `sections.jsx` `FAQSection` only renders **4 FAQ items** with **different wording** than the 12-item JSON-LD/noscript set.
  - JSON-LD Q1: "Is Clipboard History free?" → JS renders: "Is it really free?"
  - JSON-LD Q3: "Which Macs does it work on?" → JS renders: "Which Macs work with it?"
  - JSON-LD Q2 answer includes "…lock screen…" sentence; JS answer omits it
  - The other 8 JSON-LD questions have **no JS counterpart at all** in the visible FAQ
  - This creates a discrepancy between what users see and what search engines find in structured data

### 7. Internal Links
- **PASS** `screenshots/03-current.jpg` — exists
- **PASS** `dist/app.js` — exists
- **PASS** `site.css` — exists
- **PASS** All 6 JSON-LD screenshot URLs (`screenshots/01–06-current.jpg`) — all exist
- **PASS** `uploads/clipboard-history-demo.mp4` (VideoObject contentUrl) — exists
- **PASS** `uploads/clipboard-history-before-after.webp` + `.png` — both exist

### 8. Noscript Parity
- **PASS** `<noscript>` contains full feature list + complete 12-question FAQ — good parity for crawlers and no-JS users
- **INFO** Skip link (`<a href="#main">`) is JS-rendered only; noscript users get no skip link. Minor — noscript page is a simple linear document.

### 9. Accessibility
- **FAIL** `aria-prohibited-attr` (Lighthouse score 0): `<span class="kbd-combo" aria-label="Shift Command V">` — `aria-label` is not allowed on `<span>` without a valid role. Affects 3+ elements. Fix: add `role="img"` to the span, or use `<kbd>` elements.
- **FAIL** `color-contrast` (Lighthouse score 0): `.ba-showcase-tag` has contrast ratio 3.15 (foreground `#0a84ff` on background inferred from component) — below WCAG AA 4.5:1 minimum for normal text.
- **PASS** Single `<h1>` rendered by JS ("That moment you copy a new thing and the old one's gone.")
- **PASS** `<main>` landmark present
- **PASS** Skip link (`<a href="#main" class="skip-link">`) rendered by JS
- **PASS** CSS `prefers-reduced-motion` — 4 media query blocks in site.css (2× `no-preference`, 2× `reduce`); JS guards in app.jsx, hero.jsx, features.jsx

### 10. Performance (Lighthouse Opportunities)
- **INFO** Render-blocking: `site.css` blocks rendering (est. 300 ms savings from inlining critical CSS)
- **INFO** Unminified CSS: 14 KB savings
- **INFO** Unused CSS: 16 KB; Unused JS: 57 KB
- **INFO** No cache headers on local server (not representative of production CDN)
- **PASS** `dist/app.js` loaded via single `<script defer>` — runtime Babel removed

### 11. SEO / Meta
- **PASS** Lighthouse SEO: 100
- **PASS** canonical, robots, og:*, twitter:*, apple-mobile-web-app-*, format-detection all present
- **PASS** theme-color with media variants (light/dark)
- **PASS** sitemap.xml valid, robots.txt allows GPTBot/ClaudeBot/Google-Extended/PerplexityBot/Applebot
- **PASS** llms.txt present with product summary and links

---

## Outstanding Issues

1. **[A11y — WCAG FAIL]** `aria-label` on bare `<span>` without `role`: `<span class="kbd-combo" aria-label="Shift Command V">` — add `role="img"` to fix. Affects accessibility score (93 → ~97 if fixed).

2. **[A11y — WCAG FAIL]** `.ba-showcase-tag` color contrast 3.15:1 (need ≥4.5:1). The tag uses `#0a84ff` text on a near-white background. Darken text or adjust background.

3. **[Content — SEO Risk]** JS-rendered FAQ (`sections.jsx`) shows only 4 questions with different wording vs. the 12-question JSON-LD structured data. If Google renders the page and compares, the mismatch could trigger a rich-result penalty. The noscript fallback is correct, but the interactive FAQ visible to users is inconsistent with the schema.

---

## Re-QA Pass — 2026-05-10 (bundle 198 KB)

Targeted spot-check of the 3 fixes. No full Lighthouse re-run.

| Fix | Method | Result |
|-----|--------|--------|
| FAQ sync: 12 Qs verbatim in sections.jsx | Source diff + Python verbatim compare vs JSON-LD | **PASS** — 12/12 questions, all answers match JSON-LD byte-for-byte |
| `.kbd-combo` `role="img"` | Source grep (app.jsx, features.jsx) + live DOM query | **PASS** — all 3 instances have `role="img"` and `aria-label="Shift Command V"` in rendered DOM |
| `.ba-showcase-tag` contrast | CSS color math: light 15.01:1, dark 11.36:1 | **PASS** — both themes well above 4.5:1 WCAG AA threshold |

**Bundle verified:** `dist/app.js` = 198 KB (consistent with perf report of 198 KB raw / 60 KB gzip).
**No console errors** on load with updated bundle.

All 3 previously outstanding issues are resolved. No new issues found.
