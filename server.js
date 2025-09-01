// server.js
import express from "express";
import crypto from "crypto";
import cookieParser from "cookie-parser";

const app = express();
app.use(express.json());
app.use(cookieParser());

// ===== config =====
const SECRET = process.env.SECRET;
if (!SECRET) throw new Error("SECRET env var missing");
const LINKVERTISE_URL = process.env.LINKVERTISE_URL || "https://linkvertise.com/your-slug";
const GRACE_PREV_DAY  = true;              // accept yesterday's key
const TOKEN_TTL_SEC   = 24 * 60 * 60;      // token TTL
const GATE_TTL_MS     = 10 * 60 * 1000;    // /gate and lv-done window

// ===== utils =====
const b64u = {
  enc: b => Buffer.from(b).toString("base64").replace(/=/g,"").replace(/\+/g,"-").replace(/\//g,"_"),
  dec: s => Buffer.from(s.replace(/-/g,"+").replace(/_/g,"/")+["","==","="][s.length%4], "base64")
};
const hmacHex = (k,d) => crypto.createHmac("sha256", k).update(d).digest("hex");
const dateStr = (t=Date.now()) => new Date(t).toISOString().slice(0,10).replace(/-/g,""); // YYYYMMDD

function dailyKey(uid, d) {
  const raw = crypto.createHmac("sha256", SECRET).update(`${uid}:${d}`).digest();
  return raw.toString("base64").replace(/[^A-Z2-7]/gi,"").slice(0,24).toUpperCase();
}
function signToken(obj) {
  const body = b64u.enc(JSON.stringify(obj));
  const sig  = hmacHex(SECRET, body);
  return `${body}.${sig}`;
}
function verifyToken(tok) {
  if (!tok || !tok.includes(".")) return { ok:false, err:"bad token" };
  const [b,s] = tok.split(".");
  if (s !== hmacHex(SECRET,b)) return { ok:false, err:"bad sig" };
  const p = JSON.parse(b64u.dec(b).toString("utf8"));
  if (!p.uid || !p.exp) return { ok:false, err:"bad payload" };
  if (Date.now()/1000 > p.exp) return { ok:false, err:"expired" };
  return { ok:true, payload:p };
}

// CORS
app.use((_,res,next)=>{res.set("Access-Control-Allow-Origin","*");res.set("Access-Control-Allow-Headers","Content-Type");next();});

// ===== core endpoints =====
app.get("/health", (_req,res) => res.json({ ok:true }));

app.get("/get", (req,res) => {
  const uid = `${req.query.uid||""}`.trim();
  if (!/^\d+$/.test(uid)) return res.status(400).json({ ok:false, msg:"uid required" });
  res.json({ ok:true, key: dailyKey(uid, dateStr()), note:"valid today" });
});

app.post("/verify", (req,res) => {
  const { uid, key } = req.body || {};
  if (!uid || !key) return res.status(400).json({ ok:false, msg:"uid and key required" });
  const today = dateStr(), yday = dateStr(Date.now()-86400000);
  const match = key.toUpperCase()===dailyKey(uid,today) || (GRACE_PREV_DAY && key.toUpperCase()===dailyKey(uid,yday));
  if (!match) return res.json({ ok:false, msg:"Invalid key" });
  const now = Math.floor(Date.now()/1000), exp = now + TOKEN_TTL_SEC;
  res.json({ ok:true, msg:"OK", token: signToken({ uid:String(uid), iat:now, exp, v:1 }), exp });
});

app.post("/verifyToken", (req,res) => {
  const { token } = req.body || {};
  const v = verifyToken(token);
  res.json({ ok: !!v.ok, msg: v.ok ? "OK" : v.err || "invalid" });
});

// ===== hardened Linkvertise flow =====
// /gate -> issues signed flow cookie and shows a button that links to Linkvertise
app.get("/gate", (req,res) => {
  const uid = String(req.query.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).send("bad uid");
  const ts = Date.now(), nonce = crypto.randomBytes(8).toString("hex");
  const body = `${uid}.${ts}.${nonce}`, sig = hmacHex(SECRET, body);
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
  <p>Step 1: Open Linkvertise. Step 2: You will be redirected back automatically.</p>
  <form action="${LINKVERTISE_URL}" method="GET">
    <button type="submit">Open Linkvertise</button>
  </form>
</div>`);
});

// Linkvertise target-URL must point here
app.get("/lvreturn", (req,res) => {
  const raw = String(req.cookies.mh_flow || "");
  const parts = raw.split(".");
  if (parts.length !== 4) return res.status(403).send("forbidden");
  const [uid, ts, nonce, sig] = parts;
  const body = `${uid}.${ts}.${nonce}`;
  if (sig !== hmacHex(SECRET, body)) return res.status(403).send("forbidden");
  const age = Date.now() - Number(ts);
  if (!(age >= 0 && age <= GATE_TTL_MS)) return res.status(403).send("expired");
  res.cookie("mh_lv_done", "1", { maxAge: GATE_TTL_MS, httpOnly: true, sameSite: "Lax" });
  res.redirect("/keygate");
});

// Only reveal key if both flow and lv_done are valid
app.get("/keygate", (req,res) => {
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
app.listen(PORT, ()=> console.log("listening", PORT));
