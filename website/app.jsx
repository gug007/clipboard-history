/* global React, ReactDOM, Icon, HeroOverlay, DesktopMock, BeforeAfterDemo, SocialProof, StickyDownloadBar, FeatureGrid, PrivacySection, CheatsheetSection, FAQSection, DownloadSection, Footer, useTweaks, useDownloadUrl, TweaksPanel, TweakSection, TweakRadio, TweakColor */
const { useState, useEffect } = React;

// Scroll-triggered reveals: tag matching elements with .reveal and observe them.
// Skipped entirely when the user prefers reduced motion.
function useScrollReveals() {
  useEffect(() => {
    if (typeof window === "undefined") return;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduced || !("IntersectionObserver" in window)) return;

    const targets = document.querySelectorAll(
      ".section-eyebrow, .section-title, .section-lede, .feature-card, .privacy-point, .skip-card, .faq-item, .download-card"
    );
    targets.forEach((el) => el.classList.add("reveal"));

    const featuresGrid = document.querySelector(".features-grid");
    if (featuresGrid) featuresGrid.classList.add("reveal-stagger");

    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -8% 0px" }
    );
    targets.forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, []);
}

// Sticky download bar: visible once the hero scrolls out of view.
function useStickyBarReveal() {
  useEffect(() => {
    if (typeof window === "undefined") return;
    const bar = document.querySelector(".sticky-download-bar");
    const hero = document.querySelector(".hero");
    if (!bar || !hero || !("IntersectionObserver" in window)) return;
    const io = new IntersectionObserver(
      ([entry]) => {
        bar.classList.toggle("is-visible", !entry.isIntersecting);
      },
      { threshold: 0, rootMargin: "-80px 0px 0px 0px" }
    );
    io.observe(hero);
    return () => io.disconnect();
  }, []);
}

function Nav({ theme, setTheme }) {
  const [scrolled, setScrolled] = useState(false);
  const downloadUrl = useDownloadUrl();
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => window.removeEventListener("scroll", onScroll);
  }, []);
  return (
    <nav className={"nav " + (scrolled ? "scrolled" : "")} aria-label="Primary">
      <div className="container nav-inner">
        <a className="brand" href="#top" aria-label="Clipboard History — back to top">
          <span className="brand-mark" aria-hidden="true"><Icon.clipboard/></span>
          <span>Clipboard History</span>
        </a>
        <div className="nav-links">
          <a href="#features">Features</a>
          <a href="#privacy">Privacy</a>
          <a href="#shortcuts">Shortcuts</a>
          <a href="#faq">FAQ</a>
          <a href="https://github.com/gug007/clipboard-history">GitHub</a>
        </div>
        <div className="nav-actions">
          <button
            type="button"
            className="theme-toggle"
            onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
            aria-label={theme === "dark" ? "Switch to light theme" : "Switch to dark theme"}
            aria-pressed={theme === "dark"}
            title={theme === "dark" ? "Switch to light" : "Switch to dark"}
          >
            <span aria-hidden="true">{theme === "dark" ? <Icon.sun/> : <Icon.moon/>}</span>
          </button>
          <a href={downloadUrl} className="btn btn-primary">
            <span aria-hidden="true"><Icon.download/></span> Download
          </a>
        </div>
      </div>
    </nav>
  );
}

function Hero() {
  const downloadUrl = useDownloadUrl();
  return (
    <header className="hero" id="top">
      <div className="container">
        <h1>That moment you copy a new thing and the old one's <em>gone</em>.</h1>
        <p className="hero-sub">
          Press <span className="kbd-combo" role="img" aria-label="Shift Command V"><span className="kbd" aria-hidden="true">⇧</span><span className="kbd" aria-hidden="true">⌘</span><span className="kbd" aria-hidden="true">V</span></span> in any app to bring back anything you've copied — text, links, screenshots, files. Opens in under a tenth of a second.
        </p>
        <div className="hero-actions">
          <a href={downloadUrl} className="btn btn-primary btn-lg" onClick={() => window.plausible && window.plausible('Download Click')}>
            <span aria-hidden="true"><Icon.apple/></span> Download free for Mac
          </a>
          <a href="https://github.com/gug007/clipboard-history" className="btn btn-ghost btn-lg">
            <span aria-hidden="true"><Icon.github/></span> View on GitHub
          </a>
        </div>
        <div className="hero-meta">Free and open source. Works on macOS 14 or later.</div>
        <SocialProof variant="hero"/>
      </div>
      <div className="hero-stage" aria-hidden="true">
        <DesktopMock/>
      </div>
    </header>
  );
}

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "light",
  "accent": "#0a84ff"
}/*EDITMODE-END*/;

function App() {
  const [tweaks, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const theme = tweaks.theme;

  const setTheme = (t) => setTweak("theme", t);

  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme]);

  useEffect(() => {
    document.documentElement.style.setProperty("--accent", tweaks.accent);
    // accent-soft derived
    const hex = tweaks.accent.replace("#","");
    const r = parseInt(hex.slice(0,2),16), g = parseInt(hex.slice(2,4),16), b = parseInt(hex.slice(4,6),16);
    document.documentElement.style.setProperty("--accent-soft", `rgba(${r},${g},${b},${theme==="dark"?0.18:0.12})`);
  }, [tweaks.accent, theme]);

  useScrollReveals();
  useStickyBarReveal();

  return (
    <>
      <a href="#main" className="skip-link">Skip to main content</a>
      <Nav theme={theme} setTheme={setTheme}/>
      <main id="main">
        <Hero/>
        <section id="why" aria-labelledby="why-heading">
          <div className="container">
            <div className="section-eyebrow">Before &amp; after</div>
            <h2 id="why-heading" className="section-title">One shortcut between gone and saved.</h2>
            <p className="section-lede">
              Copy a new thing, lose the last one. Or copy three things in a row and need them all. <span className="kbd-combo" role="img" aria-label="Shift Command V"><span className="kbd" aria-hidden="true">⇧</span><span className="kbd" aria-hidden="true">⌘</span><span className="kbd" aria-hidden="true">V</span></span> — it's all still there.
            </p>
            <BeforeAfterDemo/>
          </div>
        </section>
        <section id="features" aria-labelledby="features-heading">
          <div className="container">
            <div className="section-eyebrow">What it does</div>
            <h2 id="features-heading" className="section-title">Everything you copy, kept.</h2>
            <FeatureGrid/>
          </div>
        </section>
        <div id="privacy"><PrivacySection/></div>
        <div id="shortcuts"><CheatsheetSection/></div>
        <div id="faq"><FAQSection/></div>
        <div id="download"><DownloadSection/></div>
      </main>
      <Footer/>

      <StickyDownloadBar/>

      <TweaksPanel title="Tweaks">
        <TweakSection title="Appearance">
          <TweakRadio
            label="Theme"
            value={tweaks.theme}
            onChange={(v) => setTweak("theme", v)}
            options={[
              { value: "light", label: "Light" },
              { value: "dark", label: "Dark" },
            ]}
          />
          <TweakColor
            label="Accent"
            value={tweaks.accent}
            onChange={(v) => setTweak("accent", v)}
            presets={["#0a84ff", "#ff375f", "#30d158", "#bf5af2", "#ff9f0a", "#5e5ce6"]}
          />
        </TweakSection>
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App/>);
