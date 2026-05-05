/* global React */

// Fallback is the version-agnostic releases page — GitHub redirects it to the
// latest release. The hook upgrades to a direct DMG URL once the API answers.
const RELEASES_PAGE = "https://github.com/gug007/clipboard-history/releases/latest";

function useDownloadUrl() {
  const [url, setUrl] = React.useState(RELEASES_PAGE);
  React.useEffect(() => {
    let cancelled = false;
    fetch("https://api.github.com/repos/gug007/clipboard-history/releases/latest")
      .then((r) => (r.ok ? r.json() : null))
      .then((data) => {
        if (cancelled || !data) return;
        const dmg = (data.assets || []).find((a) => a.name && a.name.endsWith(".dmg"));
        if (dmg && dmg.browser_download_url) setUrl(dmg.browser_download_url);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, []);
  return url;
}

window.useDownloadUrl = useDownloadUrl;
