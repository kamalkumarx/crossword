const json = (status, body) => new Response(JSON.stringify(body), {
  status,
  headers: { "content-type": "application/json", "cache-control": "no-store" }
});

const clean = (value, max = 500) => typeof value === "string" ? value.slice(0, max) : null;
const uuid = value => typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value) ? value : null;
const toHex = bytes => [...new Uint8Array(bytes)].map(byte => byte.toString(16).padStart(2, "0")).join("");

export async function onRequestPost({ request, env }) {
  // The browser calls this endpoint on its own origin. Secrets stay in Pages settings.
  const origin = request.headers.get("origin");
  if (origin && origin !== new URL(request.url).origin) return json(403, { error: "origin_not_allowed" });
  if (!env.SUPABASE_SERVICE_ROLE_KEY || !env.VISITOR_HASH_SALT) return json(503, { error: "tracking_not_configured" });

  let body;
  try { body = await request.json(); } catch { return json(400, { error: "invalid_json" }); }
  const anonymousId = uuid(body.anonymous_id);
  const sessionId = uuid(body.session_id);
  if (!anonymousId || !sessionId) return json(400, { error: "invalid_visitor" });

  const hash = async value => toHex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${env.VISITOR_HASH_SALT}:${value}`)));
  const ip = request.headers.get("cf-connecting-ip") || "unavailable";
  const visitorKey = await hash(`${ip}:${anonymousId}`);
  const rpc = body.link_only ? "link_website_visitor" : "record_website_landing";
  const payload = body.link_only ? {
    p_visitor_key: visitorKey,
    p_profile_id: uuid(body.profile_id)
  } : {
    p_visitor_key: visitorKey,
    p_ip_hash: await hash(ip),
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
    p_country_code: clean(request.cf?.country || null, 10)
  };

  try {
    const url = env.SUPABASE_URL || "https://psmkyenatcpfcsohilkc.supabase.co";
    const response = await fetch(`${url}/rest/v1/rpc/${rpc}`, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_SERVICE_ROLE_KEY,
        authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
        "content-type": "application/json"
      },
      body: JSON.stringify(payload)
    });
    if (!response.ok) {
      console.error("Visitor tracking failed", response.status);
      return json(500, { error: "tracking_failed" });
    }
    return json(200, { ok: true });
  } catch (error) {
    console.error("Visitor tracking request failed", error);
    return json(502, { error: "tracking_unavailable" });
  }
}
