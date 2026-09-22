import { createHash } from "node:crypto";

const SUPABASE_URL = process.env.SUPABASE_URL || "https://psmkyenatcpfcsohilkc.supabase.co";
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const HASH_SALT = process.env.VISITOR_HASH_SALT;
const ALLOWED_ORIGINS = new Set([
  "https://goldenwordgames.netlify.app",
  "http://localhost:8888",
  "http://localhost:3000"
]);

const json = (status, body) => new Response(JSON.stringify(body), {
  status,
  headers: { "content-type": "application/json", "cache-control": "no-store" }
});

const clean = (value, max = 500) => typeof value === "string" ? value.slice(0, max) : null;
const uuid = value => typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value) ? value : null;
const hash = value => createHash("sha256").update(`${HASH_SALT}:${value}`).digest("hex");

export default async (request, context) => {
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
  const origin = request.headers.get("origin");
  if (origin && !ALLOWED_ORIGINS.has(origin)) return json(403, { error: "origin_not_allowed" });
  if (!SERVICE_KEY || !HASH_SALT) return json(503, { error: "tracking_not_configured" });

  let body;
  try { body = await request.json(); } catch { return json(400, { error: "invalid_json" }); }
  const anonymousId = uuid(body.anonymous_id);
  const sessionId = uuid(body.session_id);
  if (!anonymousId || !sessionId) return json(400, { error: "invalid_visitor" });

  const ip = context.ip || request.headers.get("x-nf-client-connection-ip") || request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unavailable";
  const ipHash = hash(ip);
  const visitorKey = hash(`${ip}:${anonymousId}`);
  const rpc = body.link_only ? "link_website_visitor" : "record_website_landing";
  const payload = body.link_only ? {
    p_visitor_key: visitorKey,
    p_profile_id: uuid(body.profile_id)
  } : {
    p_visitor_key: visitorKey,
    p_ip_hash: ipHash,
    p_anonymous_id: anonymousId,
    p_session_id: sessionId,
    p_profile_id: uuid(body.profile_id),
    p_page_url: clean(body.page_url, 2000),
    p_landing_path: clean(body.landing_path, 500),
    p_referrer: clean(body.referrer, 2000),
    p_utm_source: clean(body.utm_source, 200),
    p_utm_medium: clean(body.utm_medium, 200),
    p_utm_campaign: clean(body.utm_campaign, 300),
    p_utm_content: clean(body.utm_content, 300),
    p_utm_term: clean(body.utm_term, 300),
    p_user_agent: clean(request.headers.get("user-agent"), 1000),
    p_country_code: clean(context.geo?.country?.code || context.geo?.country || null, 10)
  };

  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${rpc}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      authorization: `Bearer ${SERVICE_KEY}`,
      "content-type": "application/json"
    },
    body: JSON.stringify(payload)
  });
  if (!response.ok) {
    console.error("Visitor tracking failed", response.status, await response.text());
    return json(500, { error: "tracking_failed" });
  }
  return json(200, { ok: true });
};
