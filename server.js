// server.js — MoonHub backend with Linkvertise Anti-Bypass, IP/UA binding, cooldown, rate limits, gated /get, and modern UI (Node >= 20)
import express from "express";
import crypto from "crypto";
import cookieParser from "cookie-parser";

const app = express();
app.use(express.json());
app.use(cookieParser());

// ================== config ==================
const SECRET = process.env.SECRET;
if (!SECRET) throw new Error("SECRET env var missing");

// Public campaign link opened from /gate
const LINKVERTISE_URL = process.env.LINKVERTISE_URL || "https://link-target.net/1391557/2zhONTJpmRdB";

// Linkvertise Anti-Bypass publisher token
const LINKVERTISE_AUTH_TOKEN = (process.env.LINKVERTISE_AUTH_TOKEN || "4c70b600c0e85a511ded06aefa338dff4cb85be73a73b3ce7db051d802417e3f").trim();

// Gate and cooldown windows
const GATE_TTL_MS     = Number(process.env.GATE_TTL_MS || 10 * 60 * 1000);   // complete flow + claim key within 10m
const LV_COOLDOWN_MS  = Number(process.env.LV_COOLDOWN_MS || 24 * 60 * 60 * 1000); // how often a browser may complete LV
const TOKEN_TTL_SEC   = Number(process.env.TOKEN_TTL_SEC || 24 * 60 * 60);   // token TTL from /verify
const GRACE_PREV_DAY  = String(process.env.GRACE_PREV_DAY || "true") === "true";   // accept yesterday’s key
const COOKIE_SECURE   = String(process.env.COOKIE_SECURE || "true") !== "false";    // set Secure on cookies by default

// ================== helpers ==================
const b64u = {
  enc: (b) => Buffer.from(b).toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_"),
  dec: (s) => Buffer.from(s.replace(/-/g, "+").replace(/_/g, "/") + ["", "==", "="][s.length % 4], "base64")
};
const hmacHex = (k, d) => crypto.createHmac("sha256", k).update(d).digest("hex");
const dateStr = (t = Date.now()) => new Date(t).toISOString().slice(0, 10).replace(/-/g, ""); // YYYYMMDD
const shaFrag = (s) => crypto.createHash("sha256").update(String(s)).digest("hex").slice(0, 16);

function ipOf(req) {
  const xf = (req.headers["x-forwarded-for"] || "").toString();
  const ip = (xf.split(",")[0] || req.ip || "").trim();
  return ip || "0.0.0.0";
}
function ipCidrKey(ip) {
  if (ip.includes(".")) { // IPv4
    const parts = ip.split(".");
    return parts.slice(0, 3).join("."); // /24
  }
  if (ip.includes(":")) { // IPv6
    const parts = ip.split(":").filter(Boolean);
    return parts.slice(0, 4).join(":"); // /64 approx
  }
  return ip;
}

function dailyKey(uid, d) {
  const raw = crypto.createHmac("sha256", SECRET).update(`${uid}:${d}`).digest();
  return raw.toString("base64").replace(/[^A-Z2-7]/gi, "").slice(0, 24).toUpperCase();
}
function signToken(obj) {
  const body = b64u.enc(JSON.stringify(obj));
  const sig  = hmacHex(SECRET, body);
  return `${body}.${sig}`;
}
function verifyToken(tok) {
  if (!tok || !tok.includes(".")) return { ok: false, err: "bad token" };
  const [b, s] = tok.split(".");
  if (s !== hmacHex(SECRET, b)) return { ok: false, err: "bad sig" };
  const p = JSON.parse(b64u.dec(b).toString("utf8"));
  if (!p.uid || !p.exp) return { ok: false, err: "bad payload" };
  if (Date.now() / 1000 > p.exp) return { ok: false, err: "expired" };
  return { ok: true, payload: p };
}

// Rate limiter (in-memory)
const hits = new Map(); // key -> { n, exp }
function allow(key, limit, winMs) {
  const now = Date.now();
  const cur = hits.get(key);
  if (!cur || cur.exp <= now) { hits.set(key, { n: 1, exp: now + winMs }); return true; }
  if (cur.n >= limit) return false;
  cur.n += 1; return true;
}
setInterval(() => { // cleanup
  const now = Date.now();
  for (const [k, v] of hits) if (v.exp <= now) hits.delete(k);
}, 60_000).unref();

// Anti-Bypass verification
async function verifyLinkvertiseHash(hash) {
  if (!LINKVERTISE_AUTH_TOKEN) return { ok: false, detail: "no_token" };
  if (!hash || hash.length < 32)  return { ok: false, detail: "no_hash" };

  const base = "https://publisher.linkvertise.com/api/v1/anti_bypassing";
  const qs   = `token=${encodeURIComponent(LINKVERTISE_AUTH_TOKEN)}&hash=${encodeURIComponent(hash)}`;

  try {
    // POST form
    let r = await fetch(base, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: qs });
    let t = (await r.text()).trim();
    if (r.ok && t.toUpperCase() === "TRUE") return { ok: true };
    try { const j = JSON.parse(t); if (j === true || j?.valid === true || j?.status === true) return { ok: true }; } catch {}

    // POST with query
    r = await fetch(`${base}?${qs}`, { method: "POST" });
    t = (await r.text()).trim();
    if (r.ok && t.toUpperCase() === "TRUE") return { ok: true };
    try { const j = JSON.parse(t); if (j === true || j?.valid === true || j?.status === true) return { ok: true }; } catch {}

    // GET fallback
    r = await fetch(`${base}?${qs}`, { method: "GET" });
    t = (await r.text()).trim();
    if (r.ok && t.toUpperCase() === "TRUE") return { ok: true };
    try { const j = JSON.parse(t); if (j === true || j?.valid === true || j?.status === true) return { ok: true }; } catch {}

    return { ok: false, detail: `status_${r.status}`, body: t };
  } catch (e) {
    return { ok: false, detail: "fetch_error" };
  }
}

// Simple CORS for same-site fetch()
app.use((_, res, next) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  next();
});

// ================== UI theme ==================
const baseHead = `
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="dark light">
<title>MoonHub Key</title>
<style>
:root{ --bg:#0b0d10; --fg:#e7e9ee; --muted:#9aa3b2; --card:#11141a; --stroke:#1a1f28; --primary:#4c8bf5; --primary-2:#6ea0ff; --ok:#85f089; --warn:#ffd36a; }
@media (prefers-color-scheme: light){
  :root{ --bg:#f6f7fb; --fg:#0b0d10; --muted:#50607a; --card:#ffffff; --stroke:#e9edf4; --primary:#2e6cf3; --primary-2:#4a82ff; --ok:#0aa84f; --warn:#b77600; }
}
*{box-sizing:border-box} html,body{height:100%}
body{ margin:0; background: radial-gradient(1200px 600px at 20% -10%, rgba(76,139,245,.12), transparent 60%), radial-gradient(1200px 800px at 120% 20%, rgba(133,240,137,.10), transparent 55%), var(--bg); color:var(--fg); font: 16px/1.45 system-ui,-apple-system,Segoe UI,Roboto,"Helvetica Neue",Arial,"Noto Sans","Apple Color Emoji","Segoe UI Emoji"; display:grid; place-items:center; padding:24px; }
.card{ width:min(720px, 92vw); background:color-mix(in lch, var(--card) 90%, transparent); border:1px solid var(--stroke); border-radius:16px; padding:22px 20px; backdrop-filter: blur(6px); box-shadow: 0 6px 24px rgba(0,0,0,.25); }
.hdr{display:flex; align-items:center; gap:12px; margin-bottom:14px}
.logo{ width:36px;height:36px;border-radius:10px;display:grid;place-items:center; background:linear-gradient(135deg,var(--primary),var(--primary-2)); color:#fff; font-weight:700; }
.h1{font-size:18px; font-weight:650}
.row{display:flex; align-items:center; gap:10px; flex-wrap:wrap}
.pill{border:1px solid var(--stroke); background:rgba(255,255,255,.03); padding:6px 10px; border-radius:999px; color:var(--muted); font-size:13px}
.btn{ appearance:none; border:0; background:linear-gradient(180deg,var(--primary),var(--primary-2)); color:#fff; padding:11px 16px; border-radius:12px; font-weight:650; cursor:pointer; transition:transform .06s ease, filter .2s ease, box-shadow .2s ease; box-shadow:0 10px 20px rgba(76,139,245,.25); }
.btn:hover{ filter:brightness(1.05) } .btn:active{ transform:translateY(1px) }
.btn.secondary{ background:transparent; color:var(--fg); border:1px solid var(--stroke); box-shadow:none; }
.hr{height:1px; background:var(--stroke); margin:16px 0} .help{color:var(--muted); font-size:13px}
.code{ user-select:all; background:#0e1116; color:#e9eef8; border:1px solid var(--stroke); border-radius:12px; padding:12px; font-family: ui-monospace, Menlo, Consolas, monospace; font-size:15px; letter-spacing:.3px; }
.badge{color:var(--ok); font-weight:600} .warn{color:var(--warn)} .center{display:flex; gap:12px; justify-content:flex-start; align-items:center; flex-wrap:wrap}
</style>
`;

// ================== core endpoints ==================
app.get("/health", (_req, res) => res.json({ ok: true }));

// /get now requires that the LV gate was completed in this browser (mh_lv_done cookie). It also clears mh_lv_done to be single-use.
app.get("/get", (req, res) => {
  if (req.cookies.mh_lv_done !== "1") return res.status(403).json({ ok: false, msg: "gate first" });
  const uid = `${req.query.uid || ""}`.trim();
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok: false, msg: "uid required" });
  // single-use consume
  res.clearCookie("mh_lv_done", { sameSite: "Lax", httpOnly: true, secure: COOKIE_SECURE });
  return res.json({ ok: true, key: dailyKey(uid, dateStr()), note: "valid today" });
});

app.post("/verify", (req, res) => {
  const { uid, key } = req.body || {};
  if (!uid || !key) return res.status(400).json({ ok: false, msg: "uid and key required" });
  const today = dateStr(), yday = dateStr(Date.now() - 86400000);
  const match = key.toUpperCase() === dailyKey(uid, today) || (GRACE_PREV_DAY && key.toUpperCase() === dailyKey(uid, yday));
  if (!match) return res.json({ ok: false, msg: "Invalid key" });
  const now = Math.floor(Date.now() / 1000), exp = now + TOKEN_TTL_SEC;
  res.json({ ok: true, msg: "OK", token: signToken({ uid: String(uid), iat: now, exp, v: 1 }), exp });
});

app.post("/verifyToken", (req, res) => {
  const { token } = req.body || {};
  const v = verifyToken(token);
  res.json({ ok: !!v.ok, msg: v.ok ? "OK" : v.err || "invalid" });
});

// ================== flow ==================
// Step 1 — /gate: issue signed flow cookie bound to IP (/24 or IPv6 /64) and user-agent; enforce cooldown & rate limits.
app.get("/gate", (req, res) => {
  const uid = String(req.query.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).send("bad uid");

  const ipKey = ipCidrKey(ipOf(req));
  const uaKey = String(req.get("user-agent") || "").slice(0, 64);

  if (!allow("ip:" + ipKey, 30, 10 * 60 * 1000)) return res.status(429).send("slow down");
  if (!allow("uid:" + uid,   10, 10 * 60 * 1000)) return res.status(429).send("slow down");
  if (req.cookies.mh_lv_cool === "1") return res.status(429).send("Too soon");

  const ts = Date.now(), nonce = crypto.randomBytes(8).toString("hex");
  const ipH = shaFrag(ipKey), uaH = shaFrag(uaKey);
  const body = `${uid}.${ts}.${nonce}.${ipH}.${uaH}`, sig = hmacHex(SECRET, body);
  res.cookie("mh_flow", `${body}.${sig}`, { maxAge: GATE_TTL_MS, httpOnly: true, sameSite: "Lax", secure: COOKIE_SECURE });

  res.type("html").send(`<!doctype html>
${baseHead}
<body>
  <main class="card">
    <div class="hdr"><div class="logo">🌙</div><div class="h1">MoonHub · Key Gate</div></div>
    <div class="row">
      <div class="pill">UserId: <strong>${uid}</strong></div>
      <div class="pill">Window: ${Math.round(GATE_TTL_MS/60000)}m</div>
    </div>
    <div class="hr"></div>
    <p class="help">Step 1: open Linkvertise. Step 2: you will be redirected back automatically to claim the key.</p>
    <form action="${LINKVERTISE_URL}" method="GET" class="center">
      <button class="btn" type="submit">Open Linkvertise</button>
      <button class="btn secondary" type="button" onclick="location.reload()">Refresh</button>
    </form>
  </main>
</body>`);
});

// Step 2 — /lvreturn: verify flow cookie, IP/UA binding, Linkvertise hash; set lv_done and cooldown; redirect to /keygate.
app.get("/lvreturn", async (req, res) => {
  const raw = String(req.cookies.mh_flow || "");
  const parts = raw.split(".");
  if (parts.length !== 6) return res.status(403).send("forbidden");
  const [uid, ts, nonce, ipH, uaH, sig] = parts;
  const body = `${uid}.${ts}.${nonce}.${ipH}.${uaH}`;
  if (sig !== hmacHex(SECRET, body)) return res.status(403).send("forbidden");
  const age = Date.now() - Number(ts);
  if (!(age >= 0 && age <= GATE_TTL_MS)) return res.status(403).send("expired");

  const nowIpH = shaFrag(ipCidrKey(ipOf(req)));
  const nowUaH = shaFrag(String(req.get("user-agent") || "").slice(0, 64));
  if (ipH !== nowIpH || uaH !== nowUaH) return res.status(403).send("moved");

  // Rate limit checking here too
  const ipKey = ipCidrKey(ipOf(req));
  if (!allow("ip:" + ipKey, 60, 10 * 60 * 1000)) return res.status(429).send("slow down");

  const v = await verifyLinkvertiseHash(String(req.query.hash || ""));
  if (!v.ok) {
    return res.status(403).type("text/html").send(`<!doctype html>
${baseHead}
<body>
  <main class="card">
    <div class="hdr"><div class="logo">⚠️</div><div class="h1">Verification failed</div></div>
    <p class="help">Anti-bypass validation did not pass. Please try again from the start.</p>
    <div class="code">Details: ${(v.detail||"")}${v.body?("<br>"+String(v.body).replace(/</g,"&lt;")):""}</div>
    <div class="hr"></div>
    <div class="center"><a class="btn" href="/gate?uid=${uid}">Try again</a></div>
  </main>
</body>`);
  }

  // success: mark lv_done and set 24h cooldown cookie
  res.cookie("mh_lv_done", "1",  { maxAge: GATE_TTL_MS, httpOnly: true, sameSite: "Lax", secure: COOKIE_SECURE });
  res.cookie("mh_lv_cool", "1",  { maxAge: LV_COOLDOWN_MS, httpOnly: true, sameSite: "Lax", secure: COOKIE_SECURE });
  res.redirect("/keygate");
});

// Step 3 — /keygate: require valid flow cookie and lv_done
app.get("/keygate", (req, res) => {
  const raw = String(req.cookies.mh_flow || "");
  const parts = raw.split(".");
  if (parts.length !== 6) return res.status(403).send("forbidden");
  const [uid, ts, nonce, ipH, uaH, sig] = parts;
  const body = `${uid}.${ts}.${nonce}.${ipH}.${uaH}`;
  if (sig !== hmacHex(SECRET, body)) return res.status(403).send("forbidden");
  const age = Date.now() - Number(ts);
  if (!(age >= 0 && age <= GATE_TTL_MS)) return res.status(403).send("expired");
  const nowIpH = shaFrag(ipCidrKey(ipOf(req)));
  const nowUaH = shaFrag(String(req.get("user-agent") || "").slice(0, 64));
  if (ipH !== nowIpH || uaH !== nowUaH) return res.status(403).send("moved");
  if (req.cookies.mh_lv_done !== "1") return res.status(403).send("complete Linkvertise first");

  res.type("html").send(`<!doctype html>
${baseHead}
<body>
  <main class="card">
    <div class="hdr"><div class="logo">🔑</div><div class="h1">MoonHub · Get your key</div></div>
    <div class="row">
      <div class="pill">UserId: <strong>${uid}</strong></div>
      <div class="pill badge">Verified</div>
    </div>
    <div class="hr"></div>
    <div class="center">
      <button id="btn" class="btn">Receive key</button>
      <button id="copy" class="btn secondary" style="display:none">Copy</button>
    </div>
    <div id="panel" style="margin-top:12px; display:none">
      <div class="code" id="code"></div>
      <p class="help" style="margin-top:8px">Key rotates daily. Repeat after cooldown.</p>
    </div>
  </main>
<script>
async function fetchKey(u){
  const r = await fetch('/get?uid='+encodeURIComponent(u));
  if(!r.ok){ alert('Gate not satisfied or server error'); return }
  const j = await r.json();
  if(!j.ok){ alert(j.msg||'Error'); return }
  const code = document.getElementById('code');
  code.textContent = j.key;
  document.getElementById('panel').style.display = 'block';
  document.getElementById('copy').style.display = 'inline-flex';
  try { await navigator.clipboard.writeText(j.key) } catch {}
}
document.getElementById('btn').onclick = () => fetchKey(${JSON.stringify(uid)});
document.getElementById('copy').onclick = async () => {
  const v = document.getElementById('code').textContent;
  try { await navigator.clipboard.writeText(v); } catch {}
};
</script>
</body>`);
});

// ================== start ==================
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log("listening", PORT));
