import express from "express";
import crypto from "crypto";
import cookieParser from "cookie-parser";

const app = express();
app.use(express.json());
app.use(cookieParser());

const SECRET = process.env.SECRET;
if (!SECRET) throw new Error("SECRET env var missing");

const LINKVERTISE_URL = process.env.LINKVERTISE_URL || "https://linkvertise.com/your-slug";
const GRACE_PREV_DAY = true;
const TOKEN_TTL_SEC  = 24 * 60 * 60;

const b64u = {
  enc: b => Buffer.from(b).toString("base64").replace(/=/g,"").replace(/\+/g,"-").replace(/\//g,"_"),
  dec: s => Buffer.from(s.replace(/-/g,"+").replace(/_/g,"/")+["","==","="][s.length%4], "base64")
};
const hmac = (key, data) => crypto.createHmac("sha256", key).update(data).digest();
const hmacHex = (key, data) => crypto.createHmac("sha256", key).update(data).digest("hex");
const dateStr = (t=Date.now()) => new Date(t).toISOString().slice(0,10).replace(/-/g,""); // YYYYMMDD

function dailyKey(uid, d) {
  const raw = hmac(SECRET, `${uid}:${d}`);
  return raw.toString("base64").replace(/[^A-Z2-7]/gi,"").slice(0,24).toUpperCase();
}
function signToken(payloadObj) {
  const payload = JSON.stringify(payloadObj);
  const body = b64u.enc(payload);
  const sig  = hmacHex(SECRET, body);
  return `${body}.${sig}`;
}
function verifyToken(token) {
  if (typeof token !== "string" || !token.includes(".")) return { ok:false, err:"bad token" };
  const [body, sig] = token.split(".");
  const good = hmacHex(SECRET, body);
  if (sig !== good) return { ok:false, err:"bad sig" };
  const payload = JSON.parse(b64u.dec(body).toString("utf8"));
  if (!payload.uid || !payload.exp) return { ok:false, err:"bad payload" };
  if (Date.now()/1000 > payload.exp) return { ok:false, err:"expired" };
  return { ok:true, payload };
}

app.use((_,res,next)=>{res.set("Access-Control-Allow-Origin","*");res.set("Access-Control-Allow-Headers","Content-Type");next();});

app.get("/health", (_,res) => res.json({ ok:true }));

app.get("/get", (req,res) => {
  const uid = `${req.query.uid||""}`.trim();
  if (!uid) return res.status(400).json({ ok:false, msg:"uid required" });
  const today = dateStr();
  res.json({ ok:true, key: dailyKey(uid, today), note:"valid today" });
});

app.post("/verify", (req,res) => {
  const { uid, key } = req.body || {};
  if (!uid || !key) return res.status(400).json({ ok:false, msg:"uid and key required" });

  const today = dateStr();
  const yday  = dateStr(Date.now()-86400000);

  const match =
    key.toUpperCase() === dailyKey(uid, today) ||
    (GRACE_PREV_DAY && key.toUpperCase() === dailyKey(uid, yday));

  if (!match) return res.json({ ok:false, msg:"Invalid key" });

  const now = Math.floor(Date.now()/1000);
  const exp = now + TOKEN_TTL_SEC;
  const token = signToken({ uid: String(uid), iat: now, exp, v: 1 });

  res.json({ ok:true, msg:"OK", token, exp });
});

app.post("/verifyToken", (req,res) => {
  const { token } = req.body || {};
  const v = verifyToken(token);
  res.json({ ok: v.ok, msg: v.ok ? "OK" : v.err });
});

// /go: sets uid cookie then redirects to Linkvertise
app.get("/go", (req,res) => {
  const uid = String(req.query.uid || "");
  if (!/^\d+$/.test(uid)) return res.status(400).send("bad uid");
  res.cookie("moonhub_uid", uid, { maxAge: 10 * 60 * 1000, httpOnly: false, sameSite: "Lax" });
  res.redirect(LINKVERTISE_URL);
});

// /keygate: Linkvertise target. Reads uid (cookie or query), then shows a button to reveal today’s key.
app.get("/keygate", (req,res) => {
  const uid = String(req.query.uid || req.cookies.moonhub_uid || "");
  const valid = /^\d+$/.test(uid);
  res.set("Content-Type","text/html").send(`<!doctype html>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>MoonHub Key</title>
<style>
body{font-family:system-ui;margin:24px;background:#0b0b0d;color:#e6e6e6}
h2{margin:0 0 12px}
button{padding:10px 14px;font-size:16px;border:none;border-radius:8px;background:#4c8bf5;color:#fff;cursor:pointer}
button:active{transform:translateY(1px)}
pre{margin-top:16px;padding:12px;background:#111;border-radius:8px;color:#8ef58e}
a{color:#8ec6ff}
.card{padding:16px;border:1px solid #222;border-radius:12px;background:#111}
</style>
<h2>MoonHub Key</h2>
<div class=card>
  ${valid ? `<p>UserId: <b>${uid}</b></p>` : `<label>UserId: <input id=uid placeholder="e.g. 12345678" style="padding:8px;border-radius:6px;border:1px solid #333;background:#151515;color:#ddd"></label>`}
  <p>Click to reveal today’s key after completing Linkvertise.</p>
  <button id=btn>Get Today’s Key</button>
  <pre id=out style="display:none"></pre>
  <p style="opacity:.8">If nothing shows, reload this page or try again later.</p>
</div>
<script>
const uid = ${valid ? JSON.stringify(uid) : "null"};
async function fetchKey(u){
  const r = await fetch('/get?uid='+u);
  if(!r.ok){ alert('Server error'); return }
  const j = await r.json();
  if(!j.ok){ alert(j.msg||'Error'); return }
  const out = document.getElementById('out');
  out.textContent = j.key;
  out.style.display='block';
  try{ await navigator.clipboard.writeText(j.key) }catch(e){}
}
document.getElementById('btn').onclick = () => {
  if(uid) return fetchKey(uid);
  const box=document.getElementById('uid');
  if(!box.value) return alert('Enter userId');
  fetchKey(String(box.value).replace(/\\D/g,''));
};
</script>`);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, ()=> console.log("listening", PORT));
