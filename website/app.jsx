/* global React, ReactDOM, Icon, DesktopMock, BeforeAfterDemo, SocialProof, StickyDownloadBar, FeatureGrid, PrivacySection, CheatsheetSection, FAQSection, DownloadSection, Footer, useTweaks, useDownloadUrl, TweaksPanel, TweakSection, TweakRadio, TweakColor */
const { useState, useEffect, useRef } = React;

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
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    if (typeof window === "undefined") return;
    const hero = document.querySelector(".hero");
    if (!hero || !("IntersectionObserver" in window)) return;
    const io = new IntersectionObserver(
      ([entry]) => {
        setVisible(!entry.isIntersecting);
      },
      { threshold: 0, rootMargin: "-80px 0px 0px 0px" }
    );
    io.observe(hero);
    return () => io.disconnect();
  }, []);
  return visible;
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
          <a href={downloadUrl} className="btn btn-primary" onClick={() => window.plausible && window.plausible('Download Click', { props: { source: 'nav' } })}>
            <span aria-hidden="true"><Icon.download/></span> Download
          </a>
        </div>
      </div>
      <div className="container mobile-nav-links" role="group" aria-label="Page sections">
        <a href="#features">Features</a>
        <a href="#privacy">Privacy</a>
        <a href="#shortcuts">Shortcuts</a>
        <a href="#faq">FAQ</a>
      </div>
    </nav>
  );
}

function Hero({ animationsPaused, onToggleAnimations }) {
  const downloadUrl = useDownloadUrl();
  return (
    <header className="hero" id="top">
      <div className="container">
        <div className="hero-kicker"><span aria-hidden="true"/> Free clipboard manager for Mac</div>
        <h1><em>Never lose</em> what you copy on your Mac.</h1>
        <p className="hero-sub">
          Clipboard History keeps text, links, files, and folders ready to paste again. Press <span className="kbd-combo" role="img" aria-label="Shift Command V"><span className="kbd" aria-hidden="true">⇧</span><span className="kbd" aria-hidden="true">⌘</span><span className="kbd" aria-hidden="true">V</span></span> in any app to find any of your last thousand copies instantly.
        </p>
        <div className="hero-actions">
          <a href={downloadUrl} className="btn btn-primary btn-lg" onClick={() => window.plausible && window.plausible('Download Click', { props: { source: 'hero' } })}>
            <span aria-hidden="true"><Icon.apple/></span> Download free for Mac
          </a>
          <a href="#demo" className="btn btn-ghost btn-lg" onClick={() => window.plausible && window.plausible('Demo Intent')}>
            <span aria-hidden="true"><Icon.bolt/></span> Watch 38-second demo
          </a>
        </div>
        <div className="hero-meta">Free and open source. Works on macOS 14 or later.</div>
        <SocialProof variant="hero"/>
      </div>
      <div className="hero-stage">
        <div aria-hidden="true"><DesktopMock paused={animationsPaused}/></div>
        <button
          type="button"
          className="motion-toggle"
          onClick={onToggleAnimations}
          aria-pressed={animationsPaused}
        >
          <span aria-hidden="true">{animationsPaused ? "▶" : <Icon.pause/>}</span>
          {animationsPaused ? "Play demos" : "Pause demos"}
        </button>
      </div>
    </header>
  );
}

function DemoVideo({ paused = false }) {
  // Autoplay only for users who haven't asked for reduced motion; everyone
  // else gets a tap-to-play video with controls.
  const reduced =
    typeof window !== "undefined" &&
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const frameRef = useRef(null);
  const videoRef = useRef(null);
  const [shouldLoad, setShouldLoad] = useState(false);

  useEffect(() => {
    const frame = frameRef.current;
    if (!frame || !("IntersectionObserver" in window)) {
      setShouldLoad(true);
      return;
    }
    const io = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        setShouldLoad(true);
        io.disconnect();
      }
    }, { rootMargin: "240px 0px" });
    io.observe(frame);
    return () => io.disconnect();
  }, []);

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !shouldLoad) return;
    if (paused) video.pause();
    else if (!reduced) video.play().catch(() => {});
  }, [paused, reduced, shouldLoad]);

  return (
    <div className="demo-video-frame" ref={frameRef}>
      <video
        ref={videoRef}
        className="demo-video"
        src={shouldLoad ? "uploads/clipboard-history-demo.mp4" : undefined}
        poster="uploads/clipboard-history-demo-poster.webp"
        muted
        loop
        playsInline
        controls
        autoPlay={shouldLoad && !reduced && !paused}
        preload={shouldLoad ? "metadata" : "none"}
        onPlay={() => window.plausible && window.plausible('Demo Play')}
        aria-label="Screen recording: pressing Shift Command V opens the clipboard history panel; an earlier clip is selected with the arrow keys and pasted with Return."
      />
    </div>
  );
}

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "light",
  "accent": "#0a84ff"
}/*EDITMODE-END*/;

function initialTheme() {
  if (typeof document === "undefined") return TWEAK_DEFAULTS.theme;
  const theme = document.documentElement.getAttribute("data-theme");
  return theme === "dark" ? "dark" : "light";
}

function App() {
  const [tweaks, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const [theme, setThemeState] = useState(initialTheme);
  const [animationsPaused, setAnimationsPaused] = useState(false);
  const stickyBarVisible = useStickyBarReveal();

  const setTheme = (t) => {
    setThemeState(t);
    setTweak("theme", t);
    try { window.localStorage.setItem("clipboard-history-theme", t); } catch (_) {}
  };

  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
    // Keep browser chrome (mobile URL bar etc.) in sync with the toggled theme.
    document.querySelectorAll('meta[name="theme-color"]').forEach((m) => {
      m.setAttribute("content", theme === "dark" ? "#0055cc" : "#0a84ff");
    });
  }, [theme]);

  useEffect(() => {
    document.documentElement.style.setProperty("--accent", tweaks.accent);
    // accent-soft derived
    const hex = tweaks.accent.replace("#","");
    const r = parseInt(hex.slice(0,2),16), g = parseInt(hex.slice(2,4),16), b = parseInt(hex.slice(4,6),16);
    document.documentElement.style.setProperty("--accent-soft", `rgba(${r},${g},${b},${theme==="dark"?0.18:0.12})`);
  }, [tweaks.accent, theme]);

  useEffect(() => {
    document.documentElement.toggleAttribute("data-animations-paused", animationsPaused);
  }, [animationsPaused]);

  useScrollReveals();

  return (
    <>
      <a href="#main" className="skip-link">Skip to main content</a>
      <Nav theme={theme} setTheme={setTheme}/>
      <main id="main">
        <Hero
          animationsPaused={animationsPaused}
          onToggleAnimations={() => setAnimationsPaused((paused) => !paused)}
        />
        <section id="demo" className="demo-section" aria-labelledby="demo-heading">
          <div className="container">
            <div className="section-intro section-intro-center">
              <div className="section-eyebrow">See it in action</div>
              <h2 id="demo-heading" className="section-title">The real thing, in 38 seconds.</h2>
              <p className="section-lede">
                Copy a few things, press <span className="kbd-combo" role="img" aria-label="Shift Command V"><span className="kbd" aria-hidden="true">⇧</span><span className="kbd" aria-hidden="true">⌘</span><span className="kbd" aria-hidden="true">V</span></span>, pick, paste. That's the whole app.
              </p>
            </div>
            <DemoVideo paused={animationsPaused}/>
          </div>
        </section>
        <section id="features" className="features-section" aria-labelledby="features-heading">
          <div className="container">
            <div className="section-intro section-intro-center">
              <div className="section-eyebrow">What it does</div>
              <h2 id="features-heading" className="section-title">Everything you copy, kept.</h2>
              <p className="section-lede">Search instantly, keep important clips close, and paste text, links, files, or folders without breaking your flow.</p>
            </div>
            <FeatureGrid paused={animationsPaused}/>
          </div>
        </section>
        <div id="privacy"><PrivacySection/></div>
        <div id="shortcuts"><CheatsheetSection/></div>
        <div id="faq"><FAQSection/></div>
        <DownloadSection/>
      </main>
      <Footer/>

      <StickyDownloadBar visible={stickyBarVisible}/>

      <TweaksPanel title="Tweaks">
        <TweakSection title="Appearance">
          <TweakRadio
            label="Theme"
            value={theme}
            onChange={setTheme}
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
