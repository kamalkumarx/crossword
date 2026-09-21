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
      enabled: true,
      // Exact creative size: 970 × 90 pixels (wide desktop banner).
      imageUrl: window.GOLDEN_AD_ASSETS?.leaderboard || "ads/word-search-970x90.webp",
      destinationUrl: "https://goldenwordgames.netlify.app/word-search/",
      altText: "Find today's hidden words — play Word Search",
      openMode: "new_tab"
    },
    rectangle: {
      enabled: true,
      // Exact creative size: 300 × 250 pixels.
      imageUrl: window.GOLDEN_AD_ASSETS?.rectangle || "ads/sudoku-300x250.webp",
      destinationUrl: "https://goldenwordgames.netlify.app/sudoku/",
      altText: "Try today's Sudoku — easy, medium or hard",
      openMode: "new_tab"
    },
    spotlight: {
      enabled: true,
      // Recommended creative size: 300 × 250 pixels (Partner Spotlight).
      imageUrl: window.GOLDEN_AD_ASSETS?.spotlight || "ads/memory-spotlight-300x250.webp",
      destinationUrl: "https://goldenwordgames.netlify.app/memory-match/",
      altText: "Partner Spotlight — Memory Match Challenge",
      openMode: "new_tab"
    }
  },

  // Rewarded hint-video settings. The external page must allow iframe embedding.
  adPageUrl: "https://example.com/",
  sponsorWebsiteUrl: "https://example.com/",
  durationSeconds: 30,
  ctaAppearsAfterSeconds: 10
};
