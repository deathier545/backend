import express from "express";
import crypto from "crypto";

const app = express();
app.use(express.json());

// ----- required env -----
const SECRET = process.env.SECRET;
if (!SECRET) {
  throw new Error("SECRET env var missing");
}

const GRACE_PREV_DAY = true;        // accept yesterday's daily key too
const TOKEN_TTL_SEC  = 24 * 60 * 60;

// ----- helpers -----
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

// simple signed token: base64url(payload) + "." + HMAC(payload)
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

// ----- CORS (optional for browser testing) -----
app.use((_,res,next)=>{res.set("Access-Control-Allow-Origin","*");res.set("Access-Control-Allow-Headers","Content-Type");next();});

app.get("/health", (_,res) => res.json({ ok:true }));

// Return today's key for a uid
app.get("/get", (req,res) => {
  const uid = `${req.query.uid||""}`.trim();
  if (!uid) return res.status(400).json({ ok:false, msg:"uid required" });
  const today = dateStr();
  res.json({ ok:true, key: dailyKey(uid, today), note:"valid today" });
});

// Verify a submitted key. On success issue a 24h token.
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

// Re-validate a cached token so client can skip the key prompt
app.post("/verifyToken", (req,res) => {
  const { token } = req.body || {};
  const v = verifyToken(token);
  res.json({ ok: v.ok, msg: v.ok ? "OK" : v.err });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, ()=> console.log("listening", PORT));
