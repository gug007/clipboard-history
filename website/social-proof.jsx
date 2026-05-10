/* global React, Icon */

const GITHUB_REPO = "gug007/clipboard-history";
const GITHUB_STARS_API = `https://api.github.com/repos/${GITHUB_REPO}`;
const SHIELDS_FALLBACK = `https://img.shields.io/github/stars/${GITHUB_REPO}?style=flat&label=&color=222&labelColor=222`;

function formatStars(n) {
  if (n == null) return null;
  if (n >= 10000) return (n / 1000).toFixed(0) + "k";
  if (n >= 1000) return (n / 1000).toFixed(1) + "k";
  return String(n);
}

function GitHubStars() {
  const [stars, setStars] = React.useState(null);
  const [failed, setFailed] = React.useState(false);

  React.useEffect(() => {
    let cancelled = false;
    fetch(GITHUB_STARS_API)
      .then((r) => (r.ok ? r.json() : null))
      .then((data) => {
        if (cancelled) return;
        if (data && typeof data.stargazers_count === "number") {
          setStars(data.stargazers_count);
        } else {
          setFailed(true);
        }
      })
      .catch(() => {
        if (!cancelled) setFailed(true);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <a
      className="sp-pill sp-pill-stars"
      href={`https://github.com/${GITHUB_REPO}`}
      title="Star on GitHub"
    >
      <span className="sp-pill-icon"><Icon.github/></span>
      <span className="sp-pill-label">Star on GitHub</span>
      <span className="sp-pill-sep" aria-hidden="true"/>
      {failed ? (
        <img
          className="sp-pill-badge-img"
          src={SHIELDS_FALLBACK}
          alt="GitHub stars"
          loading="lazy"
          width="40"
          height="20"
        />
      ) : (
        <span className="sp-pill-count">
          <span className="sp-star" aria-hidden="true"><Icon.star/></span>
          <span className="sp-num" style={{fontVariantNumeric: "tabular-nums"}}>
            {stars == null ? "—" : formatStars(stars)}
          </span>
        </span>
      )}
    </a>
  );
}

function TrustPill({ icon, label, title }) {
  return (
    <span className="sp-pill sp-pill-static" title={title || label}>
      <span className="sp-pill-icon">{icon}</span>
      <span className="sp-pill-label">{label}</span>
    </span>
  );
}

function SocialProof({ variant = "hero" }) {
  return (
    <div className={"social-proof social-proof-" + variant} role="group" aria-label="Trust and requirements">
      <GitHubStars/>
      <TrustPill
        icon={<Icon.shield/>}
        label="Apple-notarized"
        title="Signed and notarized by Apple — opens without warnings"
      />
      <TrustPill
        icon={<Icon.apple/>}
        label="macOS 14+ · Apple Silicon + Intel"
        title="Requires macOS 14 (Sonoma) or later"
      />
    </div>
  );
}

window.SocialProof = SocialProof;
window.GitHubStars = GitHubStars;
