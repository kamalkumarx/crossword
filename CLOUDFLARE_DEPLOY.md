# Cloudflare Pages deployment for Website 1

This branch keeps the Golden Word Games front end and Supabase project. It ports the Netlify visitor-tracking endpoint to Cloudflare Pages Functions at `/api/track-visitor`. The old Netlify deployment and its function remain on the main branch until you decide to switch.

## Deploy

1. In Cloudflare, open **Workers & Pages → Create → Pages → Connect to Git**. Authorize GitHub access to `kamalkumarx/crossword` and choose this repository.
2. Select the `cloudflare-pages-migration` branch for the first preview. Set **Build command** to `exit 0` and **Build output directory** to `.` (the repository root). Deploy. The new URL will end in `.pages.dev`.
3. In your Pages project, open **Settings → Variables and Secrets**. Add these production secrets, using your existing Netlify values:
   - `SUPABASE_SERVICE_ROLE_KEY`: Supabase service-role key. **Secret**, never put this in browser code or Git.
   - `VISITOR_HASH_SALT`: the existing visitor hash salt. **Secret**; reusing it preserves the format of earlier visitor hashes.
   - `SUPABASE_URL`: `https://psmkyenatcpfcsohilkc.supabase.co` (optional: the endpoint has this public URL as a fallback).
   Redeploy after adding them. If the existing salt is unavailable, make a new random secret; past and future network-derived hashes then will not match.
4. In Supabase **Authentication → URL Configuration → Redirect URLs**, add `https://YOUR-PROJECT.pages.dev/**` (and your later custom domain). The browser now uses the active site origin for the Google OAuth return. Check your Google provider settings in Supabase if Google sign-in is used.
5. Visit the new site and test the welcome popup, Stay / Leave, each game, player registration/profile, Google sign-in, and the network request to `/api/track-visitor`. The endpoint should return `{"ok":true}` to a valid visit POST when configured; requests without configured secrets return 503.
6. Once the actual domain is chosen, replace old `goldenwordgames.netlify.app` URLs in `index.html`, `sitemap.xml`, `robots.txt`, and `site.webmanifest` as appropriate. Update ad destinations and your ad campaign landing URLs separately. Keep the Netlify site until the new site is verified.

Cloudflare Pages Functions use the Workers Free request quota. Static pages and the browser-to-Supabase calls do not invoke this Function. Check Cloudflare's current limits and usage dashboard before a large campaign.
