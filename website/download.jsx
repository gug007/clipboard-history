/* global React */

// Fallback is the version-agnostic releases page — GitHub redirects it to the
// latest release. The hook upgrades to a direct DMG URL once the API answers.
const RELEASES_PAGE = "https://github.com/gug007/clipboard-history/releases/latest";
const FALLBACK_DOWNLOAD_URL = "https://github.com/gug007/clipboard-history/releases/download/v0.0.26/ClipboardHistory-0.0.26.dmg"; /* build-injected */

// Baked in from appcast.xml by scripts/build-web.sh — shown until (or in case)
// the GitHub API answers with the live tag.
const FALLBACK_VERSION = "0.0.26"; /* build-injected */

// Every download surface shares this request. Without the shared promise the
// nav, hero, closing CTA, and sticky bar each hit GitHub independently.
let latestReleaseRequest = null;

function fetchLatestRelease() {
  if (latestReleaseRequest) return latestReleaseRequest;
  latestReleaseRequest = fetch("https://api.github.com/repos/gug007/clipboard-history/releases/latest")
    .then((r) => (r.ok ? r.json() : null))
    .then((data) => {
      if (!data) return null;
      const dmg = (data.assets || []).find((a) => a.name && a.name.endsWith(".dmg"));
      const version = typeof data.tag_name === "string" ? data.tag_name.replace(/^v/, "") : null;
      return {
        url: dmg && dmg.browser_download_url ? dmg.browser_download_url : FALLBACK_DOWNLOAD_URL,
        version: version || FALLBACK_VERSION,
      };
    })
    .catch(() => null);
  return latestReleaseRequest;
}

function useLatestRelease() {
  const [release, setRelease] = React.useState({ url: FALLBACK_DOWNLOAD_URL || RELEASES_PAGE, version: FALLBACK_VERSION });
  React.useEffect(() => {
    let cancelled = false;
    fetchLatestRelease()
      .then((data) => {
        if (cancelled || !data) return;
        setRelease(data);
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
