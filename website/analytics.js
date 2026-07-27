(() => {
  "use strict";

  const measurementId = "G-R6NFCVFNN4";
  const consentKey = "clipboard-history-analytics-consent";
  const granted = "granted";
  const denied = "denied";
  let consentBanner = null;

  const getConsent = () => {
    try {
      return localStorage.getItem(consentKey);
    } catch (_) {
      return null;
    }
  };

  const setConsent = (value) => {
    try {
      localStorage.setItem(consentKey, value);
    } catch (_) {}
  };

  const clearConsent = () => {
    try {
      localStorage.removeItem(consentKey);
    } catch (_) {}
  };

  const prepareGoogleTag = () => {
    window.dataLayer = window.dataLayer || [];
    window.gtag = window.gtag || function gtag() {
      window.dataLayer.push(arguments);
    };
  };

  const loadGoogleAnalytics = () => {
    if (window.__clipboardHistoryGoogleAnalyticsLoaded) return;

    window.__clipboardHistoryGoogleAnalyticsLoaded = true;
    window[`ga-disable-${measurementId}`] = false;
    prepareGoogleTag();
    window.gtag("consent", "default", {
      analytics_storage: "granted",
      ad_storage: "denied",
      ad_user_data: "denied",
      ad_personalization: "denied",
    });
    window.gtag("js", new Date());
    window.gtag("config", measurementId, {
      allow_google_signals: false,
      allow_ad_personalization_signals: false,
    });

    const script = document.createElement("script");
    script.async = true;
    script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(measurementId)}`;
    document.head.appendChild(script);
  };

  const deleteAnalyticsCookies = () => {
    const cookieNames = document.cookie
      .split(";")
      .map((cookie) => cookie.trim().split("=")[0])
      .filter((name) => name === "_ga" || name.startsWith("_ga_"));
    const domains = [location.hostname, ".clipboard-history.cc"];

    for (const name of cookieNames) {
      document.cookie = `${name}=; Max-Age=0; path=/; SameSite=Lax`;
      for (const domain of domains) {
        document.cookie = `${name}=; Max-Age=0; path=/; domain=${domain}; SameSite=Lax`;
      }
    }
  };

  const disableGoogleAnalytics = () => {
    window[`ga-disable-${measurementId}`] = true;
    if (window.gtag) {
      window.gtag("consent", "update", {
        analytics_storage: "denied",
        ad_storage: "denied",
        ad_user_data: "denied",
        ad_personalization: "denied",
      });
    }
    deleteAnalyticsCookies();
  };

  const removeBanner = () => {
    consentBanner?.remove();
    consentBanner = null;
  };

  const allowAnalytics = () => {
    setConsent(granted);
    loadGoogleAnalytics();
    removeBanner();
  };

  const declineAnalytics = () => {
    setConsent(denied);
    disableGoogleAnalytics();
    removeBanner();
  };

  const showBanner = (force = false) => {
    if (consentBanner || (!force && getConsent())) return;

    const banner = document.createElement("aside");
    banner.className = "analytics-consent";
    banner.setAttribute("role", "dialog");
    banner.setAttribute("aria-label", "Optional analytics");
    banner.innerHTML = `
      <div class="analytics-consent__copy">
        <strong>Help improve Clipboard History?</strong>
        <p>Optional Google Analytics measures site visits and download clicks. Google receives no data unless you allow it.</p>
      </div>
      <div class="analytics-consent__actions">
        <button type="button" class="analytics-consent__allow">Allow analytics</button>
        <button type="button" class="analytics-consent__decline">No thanks</button>
        <a href="/privacy/#website-analytics">Privacy details</a>
      </div>
    `;
    banner.querySelector(".analytics-consent__allow").addEventListener("click", allowAnalytics);
    banner.querySelector(".analytics-consent__decline").addEventListener("click", declineAnalytics);
    document.body.appendChild(banner);
    consentBanner = banner;
  };

  const resetConsent = () => {
    clearConsent();
    disableGoogleAnalytics();
    showBanner(true);
    consentBanner?.querySelector(".analytics-consent__allow")?.focus();
  };

  const track = (eventName, parameters = {}) => {
    if (getConsent() !== granted) return;
    loadGoogleAnalytics();
    window.gtag("event", eventName, parameters);
  };

  const trackDownload = (event) => {
    const link = event.target.closest?.("a[href]");
    if (!link) return;

    const url = new URL(link.href, location.href);
    if (
      url.hostname === "github.com" &&
      url.pathname.startsWith("/gug007/clipboard-history/releases")
    ) {
      track("download_click", {
        link_url: url.href,
        link_text: link.textContent.trim().slice(0, 100),
      });
    }
  };

  const init = () => {
    const consent = getConsent();
    if (consent === granted) {
      loadGoogleAnalytics();
    } else if (!consent) {
      showBanner();
    }

    document.addEventListener("click", trackDownload);
    document.querySelectorAll("[data-analytics-preferences]").forEach((button) => {
      button.addEventListener("click", resetConsent);
    });
  };

  window.clipboardAnalytics = {
    allow: allowAnalytics,
    deny: declineAnalytics,
    reset: resetConsent,
    track,
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();
