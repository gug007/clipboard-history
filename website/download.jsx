/* global React */

// Fallback is the version-agnostic releases page — GitHub redirects it to the
// latest release. The hook upgrades to a direct DMG URL once the API answers.
const RELEASES_PAGE = "https://github.com/gug007/clipboard-history/releases/latest";

// Baked in from appcast.xml by scripts/build-web.sh — shown until (or in case)
// the GitHub API answers with the live tag.
const FALLBACK_VERSION = "0.0.26"; /* build-injected */

function useLatestRelease() {
  const [release, setRelease] = React.useState({ url: RELEASES_PAGE, version: FALLBACK_VERSION });
  React.useEffect(() => {
    let cancelled = false;
    fetch("https://api.github.com/repos/gug007/clipboard-history/releases/latest")
      .then((r) => (r.ok ? r.json() : null))
      .then((data) => {
        if (cancelled || !data) return;
        const dmg = (data.assets || []).find((a) => a.name && a.name.endsWith(".dmg"));
        const version = typeof data.tag_name === "string" ? data.tag_name.replace(/^v/, "") : null;
        setRelease((prev) => ({
          url: dmg && dmg.browser_download_url ? dmg.browser_download_url : prev.url,
          version: version || prev.version,
        }));
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, []);
  return release;
}

function useDownloadUrl() {
  return useLatestRelease().url;
}

window.useLatestRelease = useLatestRelease;
window.useDownloadUrl = useDownloadUrl;
