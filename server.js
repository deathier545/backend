// server.js — MoonHub backend (Node >= 20)
// - Key system + Linkvertise anti-bypass
// - Admin presence + fast announce/notify/disconnect (poll-based)
// - Minimal CORS for Roblox HttpService/executors
// - Names: /admin/online returns {uid,label}; admin actions include {by,byUid}

import express from "express";
import crypto from "crypto";
import cookieParser from "cookie-parser";

const app = express();
app.use(express.json({ limit: "256kb" }));
app.use(cookieParser());

// ===== CORS (allow script HTTP calls) =====
app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, X-UID, X-SIG");
  if (req.method === "OPTIONS") return res.status(204).end();
  next();
});

// ===== config =====
const SECRET = process.env.SECRET;
if (!SECRET) throw new Error("SECRET env var missing");

const LINKVERTISE_URL =
  process.env.LINKVERTISE_URL || "https://link-target.net/1391557/2zhONTJpmRdB";

// Hard-coded Anti-Bypass token (use env if you prefer)
const LINKVERTISE_AUTH_TOKEN =
  process.env.LINKVERTISE_AUTH_TOKEN ||
  "4c70b600c0e85a511ded06aefa338dff4cb85be73a73b3ce7db051d802417e3f";

const GRACE_PREV_DAY = true;
const TOKEN_TTL_SEC = 24 * 60 * 60;
const GATE_TTL_MS = 10 * 60 * 1000;

// Admin gating defaults (mirror client)
const GROUP_ID = Number(process.env.GROUP_ID || 497686443);
const ADMIN_MIN_RANK = Number(process.env.ADMIN_MIN_RANK || 200);
const ADMIN_ROLE_NAMES = (process.env.ADMIN_ROLE_NAMES || "Developer,Owner")
  .split(",")
  .map((s) => s.trim().toLowerCase())
  .filter(Boolean);

// ===== utils =====
const b64u = {
  enc: (b) =>
    Buffer.from(b)
      .toString("base64")
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_"),
  // robust base64url decode
  dec: (s) => {
    const norm = s.replace(/-/g, "+").replace(/_/g, "/");
    const padLen = (4 - (norm.length % 4)) % 4;
    return Buffer.from(norm + "=".repeat(padLen), "base64");
  },
};
const hmacHex = (k, d) => crypto.createHmac("sha256", k).update(d).digest("hex");
const dateStr = (t = Date.now()) =>
  new Date(t).toISOString().slice(0, 10).replace(/-/g, "");

function dailyKey(uid, d) {
  const raw = crypto.createHmac("sha256", SECRET).update(`${uid}:${d}`).digest();
  return raw
    .toString("base64")
    .replace(/[^A-Z2-7]/gi, "")
    .slice(0, 24)
    .toUpperCase();
}
function signToken(obj) {
  const body = b64u.enc(JSON.stringify(obj));
  const sig = hmacHex(SECRET, body);
  return `${body}.${sig}`;
}
function verifyToken(tok) {
  if (!tok || !tok.includes(".")) return { ok: false, err: "bad token" };
  const [b, s] = tok.split(".");
  if (s !== hmacHex(SECRET, b)) return { ok: false, err: "bad sig" };
  let p;
  try {
    p = JSON.parse(b64u.dec(b).toString("utf8"));
  } catch {
    return { ok: false, err: "bad payload" };
  }
  if (!p.uid || !p.exp) return { ok: false, err: "bad payload" };
  if (Date.now() / 1000 > p.exp) return { ok: false, err: "expired" };
  return { ok: true, payload: p };
}

// ===== Linkvertise verifier (POST form → POST qs → GET; accept "TRUE" or JSON) =====
async function verifyLinkvertiseHash(hash) {
  if (!LINKVERTISE_AUTH_TOKEN) return { ok: false, detail: "no_token" };
  if (!hash || hash.length < 32) return { ok: false, detail: "no_hash" };

  const base = "https://publisher.linkvertise.com/api/v1/anti_bypassing";
  const qs = `token=${encodeURIComponent(
    LINKVERTISE_AUTH_TOKEN
  )}&hash=${encodeURIComponent(hash)}`;

  try {
    let r = await fetch(base, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: qs,
    });
    let t = (await r.text()).trim();
    if (r.ok && t.toUpperCase() === "TRUE") return { ok: true };
    try {
      const j = JSON.parse(t);
      if (j === true || j?.valid === true || j?.status === true) return { ok: true };
    } catch {}

    r = await fetch(`${base}?${qs}`, { method: "POST" });
    t = (await r.text()).trim();
    if (r.ok && t.toUpperCase() === "TRUE") return { ok: true };
    try {
      const j = JSON.parse(t);
      if (j === true || j?.valid === true || j?.status === true) return { ok: true };
    } catch {}

    r = await fetch(`${base}?${qs}`, { method: "GET" });
    t = (await r.text()).trim();
    if (r.ok && t.toUpperCase() === "TRUE") return { ok: true };
    try {
      const j = JSON.parse(t);
      if (j === true || j?.valid === true || j?.status === true) return { ok: true };
    } catch {}

    return { ok: false, detail: `status_${r.status}`, body: t };
  } catch {
    return { ok: false, detail: "fetch_error" };
  }
}

// ===== shared UI head =====
const baseHead = `
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="dark light">
<title>MoonHub Key</title>
<style>
:root{
  --bg:#0b0d10; --fg:#e7e9ee; --muted:#9aa3b2; --card:#11141a; --stroke:#1a1f28;
  --primary:#4c8bf5; --primary-2:#6ea0ff; --ok:#85f089; --warn:#ffd36a;
}
@media (prefers-color-scheme: light){
  :root{ --bg:#f6f7fb; --fg:#0b0d10; --muted:#50607a; --card:#ffffff; --stroke:#e9edf4; --primary:#2e6cf3; --primary-2:#4a82ff; --ok:#0aa84f; --warn:#b77600; }
}
*{box-sizing:border-box}
html,body{height:100%}
body{
  margin:0; background: radial-gradient(1200px 600px at 20% -10%, rgba(76,139,245,.12), transparent 60%),
                      radial-gradient(1200px 800px at 120% 20%, rgba(133,240,137,.10), transparent 55%),
                      var(--bg);
  color:var(--fg); font: 16px/1.45 system-ui, -apple-system, Segoe UI, Roboto, "Helvetica Neue", Arial, "Noto Sans", "Apple Color Emoji","Segoe UI Emoji";
  display:grid; place-items:center; padding:24px;
}
.card{
  width:min(720px, 92vw); background:color-mix(in lch, var(--card) 90%, transparent);
  border:1px solid var(--stroke); border-radius:16px; padding:22px 20px; backdrop-filter: blur(6px);
  box-shadow: 0 6px 24px rgba(0,0,0,.25);
}
.hdr{display:flex; align-items:center; gap:12px; margin-bottom:14px}
.logo{
  width:36px;height:36px;border-radius:10px;display:grid;place-items:center;
  background:linear-gradient(135deg,var(--primary),var(--primary-2)); color:#fff; font-weight:700;
}
.h1{font-size:18px; font-weight:650}
.row{display:flex; align-items:center; gap:10px; flex-wrap:wrap}
.pill{border:1px solid var(--stroke); background:rgba(255,255,255,.03); padding:6px 10px; border-radius:999px; color:var(--muted); font-size:13px}
.btn{
  appearance:none; border:0; background:linear-gradient(180deg,var(--primary),var(--primary-2));
  color:#fff; padding:11px 16px; border-radius:12px; font-weight:650; cursor:pointer;
  transition:transform .06s ease, filter .2s ease, box-shadow .2s ease;
  box-shadow:0 10px 20px rgba(76,139,245,.25);
}
.btn:hover{ filter:brightness(1.05) }
.btn:active{ transform:translateY(1px) }
.btn.secondary{
  background:transparent; color:var(--fg); border:1px solid var(--stroke); box-shadow:none;
}
.hr{height:1px; background:var(--stroke); margin:16px 0}
.help{color:var(--muted); font-size:13px}
.kv{display:flex; align-items:center; gap:10px}
.code{
  user-select:all; background:#0e1116; color:#e9eef8;
  border:1px solid var(--stroke); border-radius:12px; padding:12px;
  font-family: ui-monospace, Menlo, Consolas, monospace; font-size:15px; letter-spacing:.3px;
}
.copy{margin-left:auto}
.badge{color:var(--ok); font-weight:600}
.warn{color:var(--warn)}
.center{display:flex; gap:12px; justify-content:flex-start; align-items:center; flex-wrap:wrap}
</style>
`;

// ===== core endpoints =====
app.get("/health", (_req, res) => res.json({ ok: true }));

app.get("/get", (req, res) => {
  const uid = `${req.query.uid || ""}`.trim();
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok: false, msg: "uid required" });
  res.json({ ok: true, key: dailyKey(uid, dateStr()), note: "valid today" });
});

app.post("/verify", (req, res) => {
  const { uid, key } = req.body || {};
  if (!uid || !key) return res.status(400).json({ ok: false, msg: "uid and key required" });
  const today = dateStr(),
    yday = dateStr(Date.now() - 86400000);
  const ok =
    key.toUpperCase() === dailyKey(uid, today) ||
    (GRACE_PREV_DAY && key.toUpperCase() === dailyKey(uid, yday));
  if (!ok) return res.json({ ok: false, msg: "Invalid key" });
  const now = Math.floor(Date.now() / 1000),
    exp = now + TOKEN_TTL_SEC;
  res.json({
    ok: true,
    msg: "OK",
    token: signToken({ uid: String(uid), iat: now, exp, v: 1 }),
    exp,
  });
});

app.post("/verifyToken", (req, res) => {
  const { token } = req.body || {};
  const v = verifyToken(token);
  res.json({ ok: !!v.ok, msg: v.ok ? "OK" : v.err || "invalid" });
});

// ===== flow pages =====
app.get("/gate", (req, res) => {
  const uid = String(req.query.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).send("bad uid");
  const ts = Date.now(),
    nonce = crypto.randomBytes(8).toString("hex");
  const body = `${uid}.${ts}.${nonce}`,
    sig = hmacHex(SECRET, body);
  res.cookie("mh_flow", `${body}.${sig}`, {
    maxAge: GATE_TTL_MS,
    httpOnly: true,
    sameSite: "Lax",
  });

  res
    .type("html")
    .send(`<!doctype html>
${baseHead}
<body>
  <main class="card">
    <div class="hdr">
      <div class="logo">🌙</div>
      <div class="h1">MoonHub · Key Gate</div>
    </div>

    <div class="row">
      <div class="pill">UserId: <strong>${uid}</strong></div>
      <div class="pill">Window: ${Math.round(GATE_TTL_MS / 60000)}m</div>
      <div class="pill" id="count">Time left: —</div>
    </div>

    <div class="hr"></div>

    <p class="help">Step 1: open Linkvertise. Step 2: you will be redirected here to claim the key.</p>

    <form action="${LINKVERTISE_URL}" method="GET" class="center">
      <button class="btn" type="submit" rel="noopener">Open Linkvertise</button>
      <button class="btn secondary" type="button" onclick="location.reload()">Refresh</button>
      <button class="btn secondary" type="button" id="copyLv">Copy Link</button>
    </form>
    <div class="help" style="margin-top:8px; word-break:break-all">Link: ${LINKVERTISE_URL}</div>
  </main>
<script>
(function(){
  const expiry = ${ts} + (${GATE_TTL_MS});
  const el = document.getElementById('count');
  function fmt(ms){
    const s = Math.max(0, Math.floor(ms/1000));
    const m = Math.floor(s/60), r = s%60;
    return m+'m '+r+'s';
  }
  function tick(){ el.textContent = 'Time left: ' + fmt(expiry - Date.now()); }
  tick(); setInterval(tick, 1000);
  document.getElementById('copyLv').onclick = async ()=>{
    try{ await navigator.clipboard.writeText('${LINKVERTISE_URL}'); }catch{}
  };
})();
</script>
</body>`);
});

app.get("/lvreturn", async (req, res) => {
  const hash = String(req.query.hash || "");
  const raw = String(req.cookies.mh_flow || "");
  const parts = raw.split(".");
  if (parts.length !== 4) return res.status(403).send("forbidden: flow");
  const [uid, ts, nonce, sig] = parts;
  const body = `${uid}.${ts}.${nonce}`;
  if (sig !== hmacHex(SECRET, body)) return res.status(403).send("forbidden: sig");
  const age = Date.now() - Number(ts);
  if (!(age >= 0 && age <= GATE_TTL_MS)) return res.status(403).send("expired");

  const v = await verifyLinkvertiseHash(hash);
  if (!v.ok) {
    return res
      .status(403)
      .type("text/html")
      .send(`<!doctype html>
${baseHead}
<body>
  <main class="card">
    <div class="hdr"><div class="logo">⚠️</div><div class="h1">Verification failed</div></div>
    <p class="help">Anti-bypass check did not validate this session.</p>
    <div class="code">Details: ${(v.detail || "")}${
        v.body ? "<br>" + String(v.body).replace(/</g, "&lt;") : ""
      }</div>
    <div class="hr"></div>
    <div class="center">
      <a class="btn" href="/gate?uid=${uid}">Try again</a>
    </div>
  </main>
</body>`);
  }

  res.cookie("mh_lv_done", "1", {
    maxAge: GATE_TTL_MS,
    httpOnly: true,
    sameSite: "Lax",
  });
  res.redirect("/keygate");
});

app.get("/keygate", (req, res) => {
  const raw = String(req.cookies.mh_flow || "");
  const parts = raw.split(".");
  if (parts.length !== 4) return res.status(403).send("forbidden");
  const [uid, ts, nonce, sig] = parts;
  const body = `${uid}.${ts}.${nonce}`;
  if (sig !== hmacHex(SECRET, body)) return res.status(403).send("forbidden");
  const age = Date.now() - Number(ts);
  if (!(age >= 0 && age <= GATE_TTL_MS)) return res.status(403).send("expired");
  if (req.cookies.mh_lv_done !== "1")
    return res.status(403).send("complete Linkvertise first");

  res
    .type("html")
    .send(`<!doctype html>
${baseHead}
<body>
  <main class="card">
    <div class="hdr">
      <div class="logo">🔑</div>
      <div class="h1">MoonHub · Get your key</div>
    </div>

    <div class="row">
      <div class="pill">UserId: <strong>${uid}</strong></div>
      <div class="pill badge">Verified</div>
      <div class="pill" id="rotLeft">Rotates in: —</div>
    </div>

    <div class="hr"></div>

    <div class="center">
      <button id="btn" class="btn">Receive key</button>
      <button id="copy" class="btn secondary" style="display:none">Copy</button>
      <button id="save" class="btn secondary" style="display:none">Download .txt</button>
    </div>

    <div id="panel" style="margin-top:12px; display:none">
      <div class="code" id="code"></div>
      <p class="help" style="margin-top:8px">Key rotates daily. Keep this tab for reference.</p>
    </div>
  </main>

<script>
function rotTick(){
  const now = new Date();
  const midnight = new Date(now);
  midnight.setHours(24,0,0,0);
  const ms = midnight - now;
  const s = Math.max(0, Math.floor(ms/1000));
  const h = Math.floor(s/3600), m = Math.floor((s%3600)/60), r = s%60;
  document.getElementById('rotLeft').textContent = 'Rotates in: ' + h+'h '+m+'m '+r+'s';
}
setInterval(rotTick, 1000); rotTick();

async function fetchKey(u){
  const r = await fetch('/get?uid='+u);
  if(!r.ok){ alert('Server error'); return }
  const j = await r.json();
  if(!j.ok){ alert(j.msg||'Error'); return }
  const code = document.getElementById('code');
  code.textContent = j.key;
  document.getElementById('panel').style.display = 'block';
  document.getElementById('copy').style.display = 'inline-flex';
  document.getElementById('save').style.display = 'inline-flex';
}
document.getElementById('btn').onclick = () => fetchKey(${JSON.stringify(
    ""
  )}+${JSON.stringify("")} + ${JSON.stringify("")} || ${JSON.stringify(uid)});
document.getElementById('copy').onclick = async () => {
  const v = document.getElementById('code').textContent;
  try { await navigator.clipboard.writeText(v); } catch {}
};
document.getElementById('save').onclick = () => {
  const v = document.getElementById('code').textContent;
  if(!v) return;
  const blob = new Blob([v + '\\n'], { type: 'text/plain' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = 'moonhub-key.txt'; a.click();
  setTimeout(()=>URL.revokeObjectURL(url), 500);
};
</script>
</body>`);
});

// ===== simple presence + messaging (poll) =====

// in-memory presence and mailbox
const PRESENCE_TTL_MS = 20_000;
const MAILBOX_TTL_MS = 60 * 60 * 1000;
const online = new Map(); // uid -> { ts }
let seq = 0;
const mail = []; // [{id, ts, to:'*'|uid, type, text, by, byUid}]

function now() { return Date.now(); }
function prunePresence() {
  const t = now();
  for (const [uid, v] of online) if (t - v.ts > PRESENCE_TTL_MS) online.delete(uid);
}
function listOnline() {
  prunePresence();
  return Array.from(online.keys()).map((uid) => ({ uid }));
}
function pushMessage(to, type, payload) {
  const item = { id: ++seq, ts: now(), to, type, ...(payload||{}) };
  mail.push(item);
  // prune old mail
  while (mail.length && now() - mail[0].ts > MAILBOX_TTL_MS) mail.shift();
  return item;
}

// ===== name labels for users =====
const NameCache = new Map(); // uid -> {label, ts}
async function userLabel(uid) {
  uid = String(uid);
  const cached = NameCache.get(uid);
  if (cached && now() - cached.ts < 6*60*60*1000) return cached.label;
  try {
    const r = await fetch(`https://users.roblox.com/v1/users/${uid}`);
    if (r.ok) {
      const j = await r.json();
      const dn = String(j.displayName || "");
      const un = String(j.name || "");
      const label = dn && un ? `${dn} (@${un})` : (dn || (un ? `@${un}` : uid));
      NameCache.set(uid, { label, ts: now() });
      return label;
    }
  } catch {}
  const label = uid;
  NameCache.set(uid, { label, ts: now() });
  return label;
}

// Optional server-side admin check via Roblox groups API
async function isAdminServerSide(uid) {
  try {
    const r = await fetch(`https://groups.roblox.com/v2/users/${uid}/groups/roles`);
    if (!r.ok) return false;
    const j = await r.json();
    const g = (j.data || []).find((g) => g.group && g.group.id === GROUP_ID);
    if (!g) return false;
    const rank = Number((g.role && g.role.rank) || 0);
    const name = String((g.role && g.role.name) || "").toLowerCase();
    if (rank >= ADMIN_MIN_RANK) return true;
    if (ADMIN_ROLE_NAMES.includes(name)) return true;
    return false;
  } catch {
    return false;
  }
}

// presence: hello + heartbeat
app.post("/admin/hello", (req, res) => {
  const uid = String(req.body?.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok: false, msg: "uid required" });
  online.set(uid, { ts: now() });
  res.json({ ok: true });
});
app.post("/admin/heartbeat", (req, res) => {
  const uid = String(req.body?.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok: false, msg: "uid required" });
  online.set(uid, { ts: now() });
  res.json({ ok: true });
});

// online list with labels
app.get("/admin/online", async (_req, res) => {
  const users = listOnline();
  const out = await Promise.all(users.map(async (u) => ({ uid: u.uid, label: await userLabel(u.uid) })));
  res.json({ ok: true, users: out });
});

// poll messages for a specific uid
app.get("/admin/poll", (req, res) => {
  const uid = String(req.query.uid || "");
  const since = Number(req.query.since || 0);
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok: false, msg: "uid required" });
  const out = mail.filter((m) => m.id > since && (m.to === "*" || m.to === uid));
  res.json({ ok: true, next: seq, items: out });
});

// admin actions — include actor identity in payloads
app.post("/admin/announce", async (req, res) => {
  const actor = String(req.query.uid || req.headers["x-uid"] || "");
  if (!/^\d+$/.test(actor) || !(await isAdminServerSide(actor))) {
    // allow if no actor but you want to keep building; set ALLOW_UNAUTH_ADMIN=1 to bypass for testing
    if (process.env.ALLOW_UNAUTH_ADMIN !== "1") return res.status(403).json({ ok: false, msg: "forbidden" });
  }
  const text = String(req.body?.text || "").slice(0, 500);
  if (!text) return res.status(400).json({ ok: false, msg: "text required" });
  const label = await userLabel(actor);
  pushMessage("*", "announce", { text, by: label, byUid: actor });
  res.json({ ok: true, msg: "broadcast queued" });
});

app.post("/admin/notify", async (req, res) => {
  const actor = String(req.query.uid || req.headers["x-uid"] || "");
  if (!/^\d+$/.test(actor) || !(await isAdminServerSide(actor))) {
    if (process.env.ALLOW_UNAUTH_ADMIN !== "1") return res.status(403).json({ ok: false, msg: "forbidden" });
  }
  const uid = String(req.body?.uid || "");
  const text = String(req.body?.text || "").slice(0, 500);
  if (!/^\d+$/.test(uid) || !text) return res.status(400).json({ ok: false, msg: "uid/text required" });
  const label = await userLabel(actor);
  pushMessage(uid, "notify", { text, by: label, byUid: actor });
  res.json({ ok: true, msg: "notify queued" });
});

app.post("/admin/disconnect", async (req, res) => {
  const actor = String(req.query.uid || req.headers["x-uid"] || "");
  if (!/^\d+$/.test(actor) || !(await isAdminServerSide(actor))) {
    if (process.env.ALLOW_UNAUTH_ADMIN !== "1") return res.status(403).json({ ok: false, msg: "forbidden" });
  }
  const uid = String(req.body?.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok: false, msg: "uid required" });
  const label = await userLabel(actor);
  pushMessage(uid, "disconnect", { by: label, byUid: actor });
  res.json({ ok: true, msg: "disconnect queued" });
});

// Ban system - in-memory ban list
const bannedUsers = new Set();

app.post("/admin/ban", async (req, res) => {
  const actor = String(req.query.uid || req.headers["x-uid"] || "");
  if (!/^\d+$/.test(actor) || !(await isAdminServerSide(actor))) {
    if (process.env.ALLOW_UNAUTH_ADMIN !== "1") return res.status(403).json({ ok: false, msg: "forbidden" });
  }
  const uid = String(req.body?.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok: false, msg: "uid required" });
  bannedUsers.add(uid);
  const label = await userLabel(actor);
  pushMessage(uid, "ban", { by: label, byUid: actor });
  res.json({ ok: true, msg: "user banned" });
});

app.post("/admin/unban", async (req, res) => {
  const actor = String(req.query.uid || req.headers["x-uid"] || "");
  if (!/^\d+$/.test(actor) || !(await isAdminServerSide(actor))) {
    if (process.env.ALLOW_UNAUTH_ADMIN !== "1") return res.status(403).json({ ok: false, msg: "forbidden" });
  }
  const uid = String(req.body?.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok: false, msg: "uid required" });
  bannedUsers.delete(uid);
  const label = await userLabel(actor);
  pushMessage(uid, "unban", { by: label, byUid: actor });
  res.json({ ok: true, msg: "user unbanned" });
});

app.get("/admin/banned", async (req, res) => {
  const actor = String(req.query.uid || req.headers["x-uid"] || "");
  if (!/^\d+$/.test(actor) || !(await isAdminServerSide(actor))) {
    if (process.env.ALLOW_UNAUTH_ADMIN !== "1") return res.status(403).json({ ok: false, msg: "forbidden" });
  }
  const banned = Array.from(bannedUsers);
  const out = await Promise.all(banned.map(async (uid) => ({ uid, label: await userLabel(uid) })));
  res.json({ ok: true, banned: out });
});

// Game control actions
app.post("/admin/bring", async (req, res) => {
  const actor = String(req.query.uid || req.headers["x-uid"] || "");
  if (!/^\d+$/.test(actor) || !(await isAdminServerSide(actor))) {
    if (process.env.ALLOW_UNAUTH_ADMIN !== "1") return res.status(403).json({ ok: false, msg: "forbidden" });
  }
  const uid = String(req.body?.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok: false, msg: "uid required" });
  const label = await userLabel(actor);
  pushMessage(uid, "bring", { by: label, byUid: actor });
  res.json({ ok: true, msg: "bring command sent" });
});

app.post("/admin/kill", async (req, res) => {
  const actor = String(req.query.uid || req.headers["x-uid"] || "");
  if (!/^\d+$/.test(actor) || !(await isAdminServerSide(actor))) {
    if (process.env.ALLOW_UNAUTH_ADMIN !== "1") return res.status(403).json({ ok: false, msg: "forbidden" });
  }
  const uid = String(req.body?.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok: false, msg: "uid required" });
  const label = await userLabel(actor);
  pushMessage(uid, "kill", { by: label, byUid: actor });
  res.json({ ok: true, msg: "kill command sent" });
});

app.post("/admin/freeze", async (req, res) => {
  const actor = String(req.query.uid || req.headers["x-uid"] || "");
  if (!/^\d+$/.test(actor) || !(await isAdminServerSide(actor))) {
    if (process.env.ALLOW_UNAUTH_ADMIN !== "1") return res.status(403).json({ ok: false, msg: "forbidden" });
  }
  const uid = String(req.body?.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok: false, msg: "uid required" });
  const label = await userLabel(actor);
  pushMessage(uid, "freeze", { by: label, byUid: actor });
  res.json({ ok: true, msg: "freeze command sent" });
});

app.post("/admin/unfreeze", async (req, res) => {
  const actor = String(req.query.uid || req.headers["x-uid"] || "");
  if (!/^\d+$/.test(actor) || !(await isAdminServerSide(actor))) {
    if (process.env.ALLOW_UNAUTH_ADMIN !== "1") return res.status(403).json({ ok: false, msg: "forbidden" });
  }
  const uid = String(req.body?.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok: false, msg: "uid required" });
  const label = await userLabel(actor);
  pushMessage(uid, "unfreeze", { by: label, byUid: actor });
  res.json({ ok: true, msg: "unfreeze command sent" });
});

app.post("/admin/say", async (req, res) => {
  const actor = String(req.query.uid || req.headers["x-uid"] || "");
  if (!/^\d+$/.test(actor) || !(await isAdminServerSide(actor))) {
    if (process.env.ALLOW_UNAUTH_ADMIN !== "1") return res.status(403).json({ ok: false, msg: "forbidden" });
  }
  const uid = String(req.body?.uid || "");
  const message = String(req.body?.message || "").slice(0, 200);
  if (!/^\d+$/.test(uid) || !message) return res.status(400).json({ ok: false, msg: "uid/message required" });
  const label = await userLabel(actor);
  pushMessage(uid, "say", { message, by: label, byUid: actor });
  res.json({ ok: true, msg: "say command sent" });
});

// Join Game functionality
app.post("/admin/joingame", async (req, res) => {
  const actor = String(req.query.uid || req.headers["x-uid"] || "");
  if (!/^\d+$/.test(actor) || !(await isAdminServerSide(actor))) {
    if (process.env.ALLOW_UNAUTH_ADMIN !== "1") return res.status(403).json({ ok: false, msg: "forbidden" });
  }
  const uid = String(req.body?.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok: false, msg: "uid required" });
  
  try {
    // Get player's current game details via Roblox API
    const response = await fetch(`https://presence.roblox.com/v1/presence/users`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        userIds: [parseInt(uid)]
      })
    });
    
    if (!response.ok) {
      return res.status(404).json({ ok: false, msg: "player not found or not in game" });
    }
    
    const presenceData = await response.json();
    const userPresence = presenceData.userPresences && presenceData.userPresences[0];
    
    if (!userPresence || userPresence.userPresenceType !== 2) {
      return res.status(404).json({ ok: false, msg: "player not currently in a game" });
    }
    
    const placeId = userPresence.placeId;
    const gameId = userPresence.gameId;
    
    if (!placeId || !gameId) {
      return res.status(404).json({ ok: false, msg: "player not currently in a game" });
    }
    
    const label = await userLabel(actor);
    pushMessage(actor, "joingame", { 
      targetUid: uid, 
      placeId: placeId, 
      gameId: gameId,
      by: label, 
      byUid: actor 
    });
    
    res.json({ 
      ok: true, 
      msg: "join game command sent", 
      placeId: placeId, 
      gameId: gameId 
    });
  } catch (error) {
    console.error("Error getting player game details:", error);
    res.status(500).json({ ok: false, msg: "failed to get player game details" });
  }
});

// ===== start =====
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log("listening", PORT));
