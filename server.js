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
const TOKEN_TTL_SEC = 24 * 60 * 60;

const b64u = {
  enc: b => Buffer.from(b).toString("base64").replace(/=/g,"").replace(/\+/g,"-").replace(/\//g,"_"),
  dec: s => Buffer.from(s.replace(/-/g,"+").replace(/_/g,"/")+["","==","="][s.length%4], "base64")
};
const hmacHex = (k,d) => crypto.createHmac("sha256", k).update(d).digest("hex");
const dateStr = (t=Date.now()) => new Date(t).toISOString().slice(0,10).replace(/-/g,"");

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
  if (!tok || !tok.includes(".")) return { ok:false };
  const [b,s] = tok.split(".");
  if (s !== hmacHex(SECRET,b)) return { ok:false };
  const p = JSON.parse(b64u.dec(b).toString("utf8"));
  if (!p.uid || !p.exp) return { ok:false };
  if (Date.now()/1000 > p.exp) return { ok:false };
  return { ok:true, payload:p };
}

// CORS
app.use((_,res,next)=>{res.set("Access-Control-Allow-Origin","*");res.set("Access-Control-Allow-Headers","Content-Type");next();});

// Core
app.get("/health", (_,res)=>res.json({ok:true}));

app.get("/get", (req,res)=>{
  const uid = `${req.query.uid||""}`.trim();
  if (!/^\d+$/.test(uid)) return res.status(400).json({ok:false,msg:"uid required"});
  res.json({ok:true, key: dailyKey(uid, dateStr()), note:"valid today"});
});

app.post("/verify", (req,res)=>{
  const {uid,key} = req.body||{};
  if (!uid || !key) return res.status(400).json({ok:false,msg:"uid and key required"});
  const today=dateStr(), yday=dateStr(Date.now()-86400000);
  const match = key.toUpperCase()===dailyKey(uid,today) || (GRACE_PREV_DAY && key.toUpperCase()===dailyKey(uid,yday));
  if (!match) return res.json({ok:false,msg:"Invalid key"});
  const now=Math.floor(Date.now()/1000), exp=now+TOKEN_TTL_SEC;
  res.json({ok:true,msg:"OK",token:signToken({uid:String(uid),iat:now,exp,v:1}),exp});
});

app.post("/verifyToken",(req,res)=>{
  const {token}=req.body||{};
  const v=verifyToken(token);
  res.json({ok:v.ok||false, msg:v.ok?"OK":"invalid"});
});

// Flow helpers
function issueFlow(res, uid) {
  const ts=Date.now(), nonce=crypto.randomBytes(8).toString("hex");
  const body=`${uid}.${ts}.${nonce}`, sig=hmacHex(SECRET,body);
  res.cookie("mh_flow", `${body}.${sig}`, { maxAge: 10*60*1000, httpOnly:true, sameSite:"Lax" });
}
function readFlow(req) {
  const v=String(req.cookies.mh_flow||"").split(".");
  if (v.length!==4) return {ok:false};
  const [uid,ts,nonce,sig]=v, body=`${uid}.${ts}.${nonce}`;
  if (sig!==hmacHex(SECRET,body)) return {ok:false};
  if (!/^\d+$/.test(uid)) return {ok:false};
  const age=Date.now()-Number(ts); if (!(age>=0 && age<=10*60*1000)) return {ok:false};
  return {ok:true, uid};
}

// Pages
// Step 1: WindUI opens /gate
app.get("/gate", (req,res)=>{
  const uid = String(req.query.uid||"");
  if (!/^\d+$/.test(uid)) return res.status(400).send("bad uid");
  issueFlow(res, uid);
  res.set("Content-Type","text/html").send(`<!doctype html>
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
  <p>Step 1: Open Linkvertise. Step 2: After finishing, you will be sent to the key page.</p>
  <form action="/lv" method="GET">
    <button type="submit">Open Linkvertise</button>
  </form>
</div>`);
});

// Step 1.5: sets a "clicked" cookie then sends to Linkvertise
app.get("/lv", (_req,res)=>{
  res.cookie("mh_lv_clicked","1",{maxAge:10*60*1000,httpOnly:true,sameSite:"Lax"});
  res.redirect(LINKVERTISE_URL);
});

// Step 2: Linkvertise target (set this in Linkvertise dashboard)
app.get("/keygate", (req,res)=>{
  const flow=readFlow(req);
  const clicked = !!req.cookies.mh_lv_clicked;
  res.set("Content-Type","text/html").send(`<!doctype html>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>MoonHub Key</title>
<style>
body{font-family:system-ui;margin:24px;background:#0b0b0d;color:#e6e6e6}
.card{padding:16px;border:1px solid #222;border-radius:12px;background:#111}
button{padding:10px 14px;font-size:16px;border:none;border-radius:8px;background:#4c8bf5;color:#fff;cursor:pointer}
input{padding:8px;border-radius:6px;border:1px solid #333;background:#151515;color:#ddd}
pre{margin-top:16px;padding:12px;background:#111;border-radius:8px;color:#8ef58e}
.small{opacity:.75;font-size:12px}
.warn{color:#ff9}
</style>
<h2>MoonHub Key</h2>
<div class=card>
  ${clicked && flow.ok ? `<p>UserId: <b>${flow.uid}</b></p>` :
  `<p class=warn>You must start at <a href="/gate?uid=YOUR_ID">/gate</a> and click the Linkvertise button first.</p>`}
  ${flow.ok ? '' : '<p class=small>Tip: reopen from the script or visit /gate with your userId.</p>'}
  <label>Enter your Roblox userId:</label>
  <div><input id=uid placeholder="e.g. 8936389746" value="${flow.ok?flow.uid:''}"></div>
  <p class=small>Click “Receive key” only after Linkvertise.</p>
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
document.getElementById('btn').onclick = () => {
  if(!${clicked ? "true" : "false"}){ alert('Open Linkvertise first.'); return }
  const box=document.getElementById('uid');
  const v=String(box.value||"").replace(/\\D/g,'');
  if(!v){ alert('Enter userId'); return }
  fetchKey(v);
};
</script>`);
});

// Start
const PORT = process.env.PORT || 3000;
app.listen(PORT, ()=>console.log("listening", PORT));
