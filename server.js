import express from "express";
import crypto from "crypto";
import cookieParser from "cookie-parser";

const app = express();
app.use(express.json());
app.use(cookieParser());

const SECRET = process.env.SECRET;
if (!SECRET) throw new Error("SECRET env var missing");

const LINKVERTISE_URL = process.env.LINKVERTISE_URL || "https://linkvertise.com/your-slug";
const GRACE_PREV_DAY  = true;
const TOKEN_TTL_SEC   = 24 * 60 * 60;

const b64u = {
  enc: b => Buffer.from(b).toString("base64").replace(/=/g,"").replace(/\+/g,"-").replace(/\//g,"_"),
  dec: s => Buffer.from(s.replace(/-/g,"+").replace(/_/g,"/")+["","==","="][s.length%4], "base64")
};
const hmacHex = (key, data) => crypto.createHmac("sha256", key).update(data).digest("hex");
const dateStr = (t=Date.now()) => new Date(t).toISOString().slice(0,10).replace(/-/g,"");

function dailyKey(uid, d) {
  const raw = crypto.createHmac("sha256", SECRET).update(`${uid}:${d}`).digest();
  return raw.toString("base64").replace(/[^A-Z2-7]/gi,"").slice(0,24).toUpperCase();
}
function signToken(payloadObj) {
  const body = b64u.enc(JSON.stringify(payloadObj));
  const sig  = hmacHex(SECRET, body);
  return `${body}.${sig}`;
}
function verifyToken(token) {
  if (!token || !token.includes(".")) return { ok:false, err:"bad token" };
  const [body, sig] = token.split(".");
  if (sig !== hmacHex(SECRET, body)) return { ok:false, err:"bad sig" };
  const payload = JSON.parse(b64u.dec(body).toString("utf8"));
  if (!payload.uid || !payload.exp) return { ok:false, err:"bad payload" };
  if (Date.now()/1000 > payload.exp) return { ok:false, err:"expired" };
  return { ok:true, payload };
}

// CORS
app.use((_,res,next)=>{res.set("Access-Control-Allow-Origin","*");res.set("Access-Control-Allow-Headers","Content-Type");next();});

app.get("/health", (_,res) => res.json({ ok:true }));

app.get("/get", (req,res) => {
  const uid = `${req.query.uid||""}`.trim();
  if (!uid) return res.status(400).json({ ok:false, msg:"uid required" });
  res.json({ ok:true, key: dailyKey(uid, dateStr()), note:"valid today" });
});

app.post("/verify", (req,res) => {
  const { uid, key } = req.body || {};
  if (!uid || !key) return res.status(400).json({ ok:false, msg:"uid and key required" });
  const today = dateStr(), yday = dateStr(Date.now()-86400000);
  const match = key.toUpperCase()===dailyKey(uid,today) || (GRACE_PREV_DAY && key.toUpperCase()===dailyKey(uid,yday));
  if (!match) return res.json({ ok:false, msg:"Invalid key" });
  const now = Math.floor(Date.now()/1000), exp = now + TOKEN_TTL_SEC;
  return res.json({ ok:true, msg:"OK", token: signToken({ uid:String(uid), iat:now, exp, v:1 }), exp });
});

app.post("/verifyToken", (req,res) => {
  const { token } = req.body || {};
  const v = verifyToken(token);
  res.json({ ok:v.ok, msg: v.ok ? "OK" : v.err });
});

// ----- Linkvertise flow secured by signed cookie -----

function issueFlowCookie(res, uid) {
  const ts = Date.now(); // ms
  const nonce = crypto.randomBytes(8).toString("hex");
  const body = `${uid}.${ts}.${nonce}`;
  const sig  = hmacHex(SECRET, body);
  // httpOnly=false so client JS can’t read it, but we only need server; keep it simple
  res.cookie("mh_flow", `${body}.${sig}`, { maxAge: 10*60*1000, httpOnly: true, sameSite: "Lax" });
}
function checkFlowCookie(req) {
  const v = String(req.cookies.mh_flow || "");
  const parts = v.split(".");
  if (parts.length !== 4) return { ok:false };
  const [uid, ts, nonce, sig] = parts;
  const body = `${uid}.${ts}.${nonce}`;
  if (hmacHex(SECRET, body) !== sig) return { ok:false };
  if (!/^\d+$/.test(uid)) return { ok:false };
  const age = Date.now() - Number(ts);
  if (!(age >= 0 && age <= 10*60*1000)) return { ok:false };
  return { ok:true, uid };
}

// Step 1: from WindUI
app.get("/go", (req,res) => {
  const uid = String(req.query.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).send("bad uid");
  issueFlowCookie(res, uid);
  res.redirect(LINKVERTISE_URL);
});

// Step 2: Linkvertise target
app.get("/keygate", (req,res) => {
  const flow = checkFlowCookie(req);
  if (!flow.ok) return res.status(403).send("forbidden");
  const uid = flow.uid;
  res.set("Content-Type","text/html").send(`<!doctype html>
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
  <button id=btn>Get Today’s Key</button>
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
document.getElementById('btn').onclick = ()=>fetchKey(${JSON.stringify(uid)});
</script>`);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, ()=> console.log("listening", PORT));
