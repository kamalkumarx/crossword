// GOLDEN WORD GAMES — ADVERTISEMENT CONFIGURATION
// Change only this file when you want to add or replace an advertisement.
//
// IMAGE / ANIMATION FILES
// 1) Upload the creative into the /ads folder in GitHub.
// 2) Recommended extensions: .webp or .jpg for a still image, .gif for animation.
//    .png is also supported. Keep each file below 1 MB where possible.
// 3) Set enabled: true and change imageUrl and destinationUrl below.
//
// OPEN MODE
// "fullscreen_overlay" = keeps the visitor inside this fullscreen game and loads
// the sponsor in an iframe. The sponsor website MUST allow HTTPS iframe embedding.
// "new_tab" = works with almost every sponsor website, but browsers do not allow
// this site to force an external tab into fullscreen.
window.GOLDEN_AD_CONFIG = {
  placements: {
    leaderboard: {
      enabled: false,
      // Exact creative size: 970 × 90 pixels (wide desktop banner).
      imageUrl: "ads/ad-970x90.gif",
      destinationUrl: "https://example.com/",
      altText: "Sponsored advertisement",
      openMode: "fullscreen_overlay"
    },
    rectangle: {
      enabled: false,
      // Exact creative size: 300 × 250 pixels.
      imageUrl: "ads/ad-300x250.gif",
      destinationUrl: "https://example.com/",
      altText: "Sponsored advertisement",
      openMode: "fullscreen_overlay"
    },
    spotlight: {
      enabled: false,
      // Recommended creative size: 300 × 250 pixels (Partner Spotlight).
      imageUrl: "ads/ad-spotlight-300x250.gif",
      destinationUrl: "https://example.com/",
      altText: "Partner spotlight advertisement",
      openMode: "fullscreen_overlay"
    }
  },

  // Rewarded hint-video settings. The external page must allow iframe embedding.
  adPageUrl: "https://example.com/",
  sponsorWebsiteUrl: "https://example.com/",
  durationSeconds: 30,
  ctaAppearsAfterSeconds: 10
};
