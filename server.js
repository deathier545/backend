// server.js — MoonHub key backend with Linkvertise Anti-Bypass
import express from "express";
import crypto from "crypto";
import cookieParser from "cookie-parser";
import fetch from "node-fetch"; // works on any Node; OK with Node >=20 too

const app = express();
app.use(express.json());
app.use(cookieParser());

// ===== config =====
const SECRET = process.env.SECRET;
if (!SECRET) throw new Error("SECRET env var missing");

// Public link users are sent to from /gate (your Linkvertise campaign)
const LINKVERTISE_URL =
  process.env.LINKVERTISE_URL ||
  "https://link-target.net/1391557/2zhONTJpmRdB"; // default to your new link

// Token for Linkvertise Anti-Bypass API
const LINKVERTISE_AUTH_TOKEN = process.env.LINKVERTISE_AUTH_TOKEN || "";

const GRACE_PREV_DAY = true;          // accept yesterday's key
const TOKEN_TTL_SEC  = 24 * 60 * 60;  // /verify token TTL
const GATE_TTL_MS    = 10 * 60 * 1000; // time window to complete LV and claim key

// ===== utils =====
const b64u = {
  enc: b => Buffer.from(b).toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_"),
  dec: s => Buffer.from(s.replace(/-/g, "+").replace(/_/g, "/") + ["", "==", "="][s.length % 4], "base64")
};
const hmacHex = (k, d) => crypto.createHmac("sha256", k).update(d).digest("hex");
const dateStr = (t = Date.now()) => new Date(t).toISOString().slice(0, 10).replace(/-/g, ""); // YYYYMMDD

function dailyKey(uid, d) {
  const raw = crypto.createHmac("sha256", SECRET).update(`${uid}:${d}`).digest();
  return raw.toString("base64").replace(/[^A-Z2-7]/gi, "").slice(0, 24).toUpperCase();
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
  const p = JSON.parse(b64u.dec(b).toString("utf8"));
  if (!p.uid || !p.exp) return { ok: false, err: "bad payload" };
  if (Date.now() / 1000 > p.exp) return { ok: false, err: "expired" };
  return { ok: true, payload: p };
}

// Robust verifier: tries POST then GET and logs responses
async function verifyLinkvertiseHash(hash) {
  if (!LINKVERTISE_AUTH_TOKEN) {
    console.warn("LINKVERTISE_AUTH_TOKEN missing");
    return { ok: false, detail: "no_token" };
  }
  if (!hash || hash.length < 32) {
    console.warn("LV hash missing/short:", hash);
    return { ok: false, detail: "no_hash" };
  }
  const url = `https://publisher.linkvertise.com/api/v1/anti_bypassing?token=${encodeURIComponent(
    LINKVERTISE_AUTH_TOKEN
  )}&hash=${encodeURIComponent(hash)}`;
  try {
    let r = await fetch(url, { method: "POST" });
    let t = (await r.text()).trim();
    console.log("LV POST", r.status, t);
    if (r.ok && (t === "TRUE" || t.toUpperCase() === "TRUE")) return { ok: true };
    try {
      const j = JSON.parse(t);
      if (j === true || j?.valid === true) return { ok: true };
    } catch {}
    r = await fetch(url, { method: "GET" });
    t = (await r.text()).trim();
    console.log("LV GET ", r.status, t);
    if (r.ok && (t === "TRUE" || t.toUpperCase() === "TRUE")) return { ok: true };
    try {
      const j = JSON.parse(t);
      if (j === true || j?.valid === true) return { ok: true };
    } catch {}
    return { ok: false, detail: `status_${r.status}`, body: t };
  } catch (e) {
    console.error("LV verify error:", e);
    return { ok: false, detail: "fetch_error" };
  }
}

// simple CORS
app.use((_, res, next) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  next();
});

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
  const match =
    key.toUpperCase() === dailyKey(uid, today) ||
    (GRACE_PREV_DAY && key.toUpperCase() === dailyKey(uid, yday));
  if (!match) return res.json({ ok: false, msg: "Invalid key" });
  const now = Math.floor(Date.now() / 1000),
    exp = now + TOKEN_TTL_SEC;
  res.json({ ok: true, msg: "OK", token: signToken({ uid: String(uid), iat: now, exp, v: 1 }), exp });
});

app.post("/verifyToken", (req, res) => {
  const { token } = req.body || {};
  const v = verifyToken(token);
  res.json({ ok: !!v.ok, msg: v.ok ? "OK" : v.err || "invalid" });
});

// ===== hardened Linkvertise flow =====

// Step 1: script opens this. Sets signed flow cookie. Shows button to LV.
app.get("/gate", (req, res) => {
  const uid = String(req.query.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).send("bad uid");
  const ts = Date.now(),
    nonce = crypto.randomBytes(8).toString("hex");
  const body = `${uid}.${ts}.${nonce}`,
    sig = hmacHex(SECRET, body);
  res.cookie("mh_flow", `${body}.${sig}`, { maxAge: GATE_TTL_MS, httpOnly: true, sameSite: "Lax" });
  res.type("html").send(`<!doctype html>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>MoonHub Key Gate</title>
<style>
body{font-family:system-ui;margin:24px;background:#0b0b0d;color:#e6e6e6}
.card{padding:16px;border:1px solid #222;border-radius:12px;background:#111}
button{padding:10px 14px;font-size:16px;border:none;border-radius:8px;background:#4c8bf5;color:#fff;cursor:pointer}
a{color:#8ec6ff}
</style>
<h2>MoonHub Key</h2>
<div class=card>
  <p>UserId: <b>${uid}</b></p>
  <p>Step 1: Open Linkvertise. After completion you will be redirected back automatically.</p>
  <form action="${LINKVERTISE_URL}" method="GET">
    <button type="submit">Open Linkvertise</button>
  </form>
</div>`);
});

// Step 2: LV target — includes ?hash=...; verify via API; then continue.
app.get("/lvreturn", async (req, res) => {
  const hash = String(req.query.hash || "");
  console.log("LV return hit. hash len:", hash.length, "head:", hash.slice(0, 8));
  const raw = String(req.cookies.mh_flow || "");
  const parts = raw.split(".");
  if (parts.length !== 4) {
    console.warn("flow cookie missing");
    return res.status(403).send("forbidden: flow");
  }
  const [uid, ts, nonce, sig] = parts;
  const body = `${uid}.${ts}.${nonce}`;
  if (sig !== hmacHex(SECRET, body)) {
    console.warn("flow sig mismatch");
    return res.status(403).send("forbidden: sig");
  }
  const age = Date.now() - Number(ts);
  if (!(age >= 0 && age <= GATE_TTL_MS)) {
    console.warn("flow expired", age);
    return res.status(403).send("expired");
  }

  const v = await verifyLinkvertiseHash(hash);
  if (!v.ok) {
    console.warn("LV verify failed:", v);
    return res
      .status(403)
      .type("text/plain")
      .send(
        "invalid hash from Linkvertise. Ensure Anti-Bypass is enabled, Target URL = /lvreturn, and do not reload.\nDetails: " +
          (v.detail || "") +
          (v.body ? "\nBody: " + v.body : "")
      );
  }

  res.cookie("mh_lv_done", "1", { maxAge: GATE_TTL_MS, httpOnly: true, sameSite: "Lax" });
  res.redirect("/keygate");
});

// Step 3: key page — requires both cookies valid.
app.get("/keygate", (req, res) => {
  const raw = String(req.cookies.mh_flow || "");
  const parts = raw.split(".");
  if (parts.length !== 4) return res.status(403).send("forbidden");
  const [uid, ts, nonce, sig] = parts;
  const body = `${uid}.${ts}.${nonce}`;
  if (sig !== hmacHex(SECRET, body)) return res.status(403).send("forbidden");
  const age = Date.now() - Number(ts);
  if (!(age >= 0 && age <= GATE_TTL_MS)) return res.status(403).send("expired");
  if (req.cookies.mh_lv_done !== "1") return res.status(403).send("complete Linkvertise first");

  res.type("html").send(`<!doctype html>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>MoonHub Key</title>
<style>
body{font-family:system-ui;margin:24px;background:#0b0b0d;color:#e6e6e6}
button{padding:10px 14px;font-size:16px;border:none;border-radius:8px;background:#4c8bf5;color:#fff;cursor:pointer}
pre{margin-top:16px;padding:12px;background:#111;border-radius:8px;color:#8ef58e}
.card{padding:16px;border:1px solid #222;border-radius:12px;background:#111}
</style>
<h2>MoonHub Key</h2>
<div class=card>
  <p>UserId: <b>${uid}</b></p>
  <button id=btn>Receive key</button>
  <pre id=out style="display:none"></pre>
</div>
<script>
async function fetchKey(u){
  const r = await fetch('/get?uid='+u);
  if(!r.ok){ alert('Server error'); return }
  const j = await r.json();
  if(!j.ok){ alert(j.msg||'Error'); return }
  const out = document.getElementById('out');
  out.textContent = j.key; out.style.display='block';
  try{ await navigator.clipboard.writeText(j.key) }catch(e){}
}
document.getElementById('btn').onclick = () => fetchKey(${JSON.stringify(uid)});
</script>`);
});

// ===== start =====
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log("listening", PORT));
