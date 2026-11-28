// Continuum demo reader ("game B"): reads a ContentRef from Sui, loads its record from Walrus,
// shows it in its own way, walks the on-chain lineage, and can publish a remix (wallet signs).
import { Transaction } from '@mysten/sui/transactions';
import { getWallets } from '@mysten/wallet-standard';
const CONFIG = window.CONTINUUM_DEMO ?? {};

const GQL = 'https://graphql.testnet.sui.io/graphql';
const AGG = 'https://aggregator.walrus-testnet.walrus.space';
const PUB = 'https://walrus-testnet-publisher.nodes.guru';
const MAX_RECORD = 120_000;
const ID_RE = /^0x[0-9a-fA-F]{1,64}$/;
const BLOB_RE = /^[A-Za-z0-9_-]{43,44}$/;
const EXPLORER = (id) => `https://suiscan.xyz/testnet/object/${id}`;
const TX = (d) => `https://suiscan.xyz/testnet/tx/${d}`;

const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const short = (id) => (id ? `${id.slice(0, 6)}…${id.slice(-4)}` : '');

// ---------- Sui reads ----------
async function gql(query, variables) {
  const r = await fetch(GQL, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ query, variables }) });
  const j = await r.json();
  if (j.errors) throw new Error(j.errors[0].message);
  return j.data;
}
async function readRef(id) {
  const d = await gql('query($id: SuiAddress!){ object(address:$id){ address asMoveObject{ contents{ type{ repr } json } } } }', { id });
  const c = d.object?.asMoveObject?.contents;
  if (!c) throw new Error(`no object ${short(id)} on testnet`);
  return { id, type: c.type.repr, f: c.json };
}
const isContentRef = (t) => /::content_ref::ContentRef$/.test(t);

/** Find the verified source object id inside a Provenance JSON (enum shapes vary by API version). */
function sourceOf(prov) {
  if (!prov) return null;
  const src = prov.source ?? prov;
  const walk = (x) => {
    if (!x || typeof x !== 'object') return null;
    if (typeof x.id === 'string' && ID_RE.test(x.id)) return { id: x.id, type: x.type_name?.name ?? x.type_name ?? '' };
    for (const v of Object.values(x)) { const r = walk(v); if (r) return r; }
    return null;
  };
  return walk(src);
}
const deriverOf = (prov) => prov?.deriver?.name ?? prov?.deriver ?? '';

/** Follow verified parents up to the original (max 12 hops). */
async function lineage(id) {
  const chain = [];
  let cur = id;
  for (let i = 0; i < 12 && cur; i++) {
    const o = await readRef(cur);
    const node = { ...o, verified: false, parentId: null };
    if (isContentRef(o.type)) {
      const p = o.f.parent; // Option<Provenance>: null or the value
      const s = sourceOf(p);
      if (s) { node.parentId = s.id; node.verified = true; node.deriver = deriverOf(p); node.by = p.by; }
    }
    chain.push(node);
    if (!isContentRef(o.type)) break; // reached a non-content object (e.g. a koi)
    cur = node.parentId;
  }
  return chain;
}

// ---------- Walrus reads ----------
async function readRecord(blobId) {
  if (!BLOB_RE.test(blobId)) throw new Error('bad blob id');
  const r = await fetch(`${AGG}/v1/blobs/${blobId}`);
  if (!r.ok) throw new Error(`Walrus: ${r.status}`);
  const buf = await r.arrayBuffer();
  if (buf.byteLength > MAX_RECORD) throw new Error('record too big');
  const rec = JSON.parse(new TextDecoder().decode(buf));
  if (rec?.schema !== 'continuum.content/0') throw new Error('not a continuum.content/0 record');
  return rec;
}

// ---------- rendering (game B's own view of the content) ----------
const GAME_NAMES = { 'every-one-counts': 'Every One Counts', 'continuum-demo': 'Continuum demo' };
const gameName = (g) => GAME_NAMES[g] ?? g;

function renderRun(file) {
  if (!file || !Array.isArray(file.waves)) return '<p class="muted">This game doesn\'t know how to draw this body.</p>';
  const waves = file.waves.slice(0, 10).map((w, i) => {
    const n = (w.foes ?? []).reduce((a, f) => a + (Number(f.count) || 0), 0);
    const last = i === file.waves.length - 1;
    return `<li class="${last ? 'boss' : ''}"><span class="wn">${last ? 'Boss' : `Wave ${i + 1}`}</span><span class="wname">${esc(w.name)}</span><span class="wcount">${n}</span></li>`;
  }).join('');
  return `<p class="boss-line">Boss: <b>${esc(file.boss?.name)}</b></p><ol class="waves">${waves}</ol>`;
}

function renderRecord(rec, ref) {
  const o = rec.origin ?? {};
  const label = rec.kind === 'run' ? 'Run' : rec.kind;
  const play = rec.game === 'every-one-counts' && ref?.f?.blob_id
    ? `<a class="btn ghost" href="https://ones.suikoi.life/?walrus=${encodeURIComponent(ref.f.blob_id)}" target="_blank" rel="noopener">Play it in Every One Counts</a>` : '';
  return `
    <div class="card">
      <div class="kicker">${esc(label)} · made in <b>${esc(gameName(o.game || rec.game))}</b> by <b>${esc(o.author)}</b></div>
      <h2>${esc(rec.name)}</h2>
      <p class="blurb">${esc(rec.body?.blurb ?? '')}</p>
      ${rec.kind === 'run' ? renderRun(rec.body?.file) : '<p class="muted">Body shown as data only.</p>'}
      <p class="small muted">Record on Walrus: <a href="${AGG}/v1/blobs/${esc(ref.f.blob_id)}" target="_blank" rel="noopener">${esc(short(ref.f.blob_id))}</a> · its own parent reference: ${esc(o.parent ?? 'none')} (a claim)</p>
      <div class="row">${play}</div>
    </div>`;
}

function renderChain(chain) {
  const items = chain.map((n, i) => {
    const f = n.f ?? {};
    const isRef = isContentRef(n.type);
    const title = isRef ? `${esc(f.name)} <span class="muted">· ${esc(gameName(f.game))} · ${esc(f.kind)} · by ${esc(f.author)}</span>` : `${esc(n.type.split('::').slice(-1)[0])} object`;
    const link = n.verified
      ? `<div class="link ok">made from ↓ · verified by <code>provenance::derive</code></div>`
      : (i < chain.length - 1 ? '' : `<div class="link root">${isRef ? 'original' : 'source object'}</div>`);
    return `<li><div class="node"><a href="${EXPLORER(n.id)}" target="_blank" rel="noopener"><code>${short(n.id)}</code></a> ${title}</div>${link}</li>`;
  }).join('');
  return `<ol class="chain">${items}</ol>`;
}

// ---------- remix (wallet) ----------
let wallet = null, account = null;
function suiWallets() {
  return getWallets().get().filter((w) => w.features['sui:signAndExecuteTransaction'] && w.features['standard:connect']);
}
async function connect() {
  const ws = suiWallets();
  if (!ws.length) throw new Error('No Sui wallet found. Install Slush (or another Sui wallet) and reload.');
  wallet = ws[0];
  const r = await wallet.features['standard:connect'].connect();
  account = (r.accounts ?? wallet.accounts)[0];
  if (!account) throw new Error('wallet gave no account');
  $('#who').textContent = `${wallet.name}: ${short(account.address)}`;
}

const TWISTS = {
  rush: { label: 'Goose Rush: double every goose', apply: (f) => ({ ...f, waves: f.waves.map((w) => ({ ...w, foes: (w.foes ?? []).map((x) => (x.foe === 'goose' ? { ...x, count: x.count * 2 } : x)) })) }) },
  short: { label: 'Speedrun: first two waves, then the boss', apply: (f) => ({ ...f, waves: [...f.waves.slice(0, 2), f.waves[f.waves.length - 1]] }) },
};

async function putBlob(text) {
  const r = await fetch(`${PUB}/v1/blobs?epochs=53`, { method: 'PUT', body: text });
  const j = await r.json();
  const id = j.newlyCreated?.blobObject?.blobId ?? j.alreadyCertified?.blobId;
  if (!r.ok || !id) throw new Error(`Walrus publisher: ${j.error?.message ?? r.status}`);
  return id;
}

async function remix(parentRef, parentRec, twistKey) {
  if (!account) await connect();
  const t = TWISTS[twistKey];
  const name = `${parentRec.name}, ${t.label.split(':')[0]}`.slice(0, 80);
  const rec = {
    schema: 'continuum.content/0', game: 'continuum-demo', kind: parentRec.kind, id: `r-${Date.now().toString(36)}`, name,
    origin: { author: account.address, parent: `sui:${parentRef.id}`, game: 'continuum-demo' },
    body: { ...parentRec.body, blurb: `${t.label}. Remixed from ${parentRec.name}.`, file: t.apply(parentRec.body.file) },
    assets: {}, published: new Date().toISOString(),
  };
  status('Storing the remix on Walrus…');
  const blobId = await putBlob(JSON.stringify(rec));
  status('Approve the transaction in your wallet…');
  const tx = new Transaction();
  tx.moveCall({
    target: `${CONFIG.package}::content_ref::remix`,
    typeArguments: [`${CONFIG.package}::content_ref::ContentRef`],
    arguments: [tx.object(parentRef.id), tx.pure.string('continuum-demo'), tx.pure.string(rec.kind), tx.pure.string(account.address), tx.pure.string(name), tx.pure.string(blobId)],
  });
  const res = await wallet.features['sui:signAndExecuteTransaction'].signAndExecuteTransaction({ transaction: tx, account, chain: 'sui:testnet' });
  status('Waiting for Sui…');
  const newId = await createdRef(res.digest);
  status(`Done. <a href="${TX(res.digest)}" target="_blank" rel="noopener">Transaction</a>`, true);
  if (newId) { $('#refId').value = newId; history.replaceState(null, '', `?ref=${newId}`); await load(newId); }
}
async function createdRef(digest) {
  for (let i = 0; i < 20; i++) {
    try {
      const d = await gql('query($d: String!){ transaction(digest:$d){ effects{ objectChanges{ nodes{ address idCreated outputState{ asMoveObject{ contents{ type{ repr } } } } } } } } }', { d: digest });
      const nodes = d.transaction?.effects?.objectChanges?.nodes ?? [];
      const n = nodes.find((x) => x.idCreated && isContentRef(x.outputState?.asMoveObject?.contents?.type?.repr ?? ''));
      if (n) return n.address;
    } catch { /* not indexed yet */ }
    await new Promise((r) => setTimeout(r, 1500));
  }
  return null;
}

// ---------- page ----------
function status(html, keep) { const el = $('#status'); el.innerHTML = html; el.hidden = !html; if (!keep) el.classList.remove('done'); else el.classList.add('done'); }

async function load(id) {
  status('');
  $('#out').innerHTML = '<p class="muted">Reading Sui…</p>';
  try {
    if (!ID_RE.test(id)) throw new Error('Enter a ContentRef object id (0x…)');
    const chain = await lineage(id);
    const head = chain[0];
    if (!isContentRef(head.type)) throw new Error('That object is not a ContentRef');
    const rec = await readRecord(head.f.blob_id);
    const remixable = rec.kind === 'run' && Array.isArray(rec.body?.file?.waves) && CONFIG.package;
    $('#out').innerHTML = `
      <section><h3>1 · The content</h3>${renderRecord(rec, head)}</section>
      <section><h3>2 · Lineage on Sui</h3>${renderChain(chain)}</section>
      ${remixable ? `<section><h3>3 · Remix it here</h3>
        <p class="small">Makes a new record on Walrus and a new ContentRef whose parent is <code>${short(head.id)}</code>, linked with <code>derive</code>. Needs a Sui wallet on <b>testnet</b> with a little testnet SUI.</p>
        <div class="row">${Object.entries(TWISTS).map(([k, t]) => `<button class="btn" data-twist="${k}">${esc(t.label)}</button>`).join('')}</div>
      </section>` : ''}`;
    document.querySelectorAll('[data-twist]').forEach((b) => b.addEventListener('click', () => remix(head, rec, b.dataset.twist).catch((e) => status(esc(e.message ?? e)))));
  } catch (e) {
    $('#out').innerHTML = `<p class="err">${esc(e.message ?? e)}</p>`;
  }
}

function init() {
  const q = new URLSearchParams(location.search).get('ref');
  const start = q || CONFIG.demo?.remix || CONFIG.demo?.original || '';
  $('#refId').value = start;
  $('#go').addEventListener('click', () => load($('#refId').value.trim()));
  $('#refId').addEventListener('keydown', (e) => { if (e.key === 'Enter') load($('#refId').value.trim()); });
  $('#connect').addEventListener('click', () => connect().catch((e) => status(esc(e.message ?? e))));
  const ex = [['Original (Every One Counts)', CONFIG.demo?.original], ['Remix (Continuum demo)', CONFIG.demo?.remix]].filter(([, v]) => v);
  $('#examples').innerHTML = ex.map(([l, v]) => `<a href="?ref=${v}">${esc(l)}</a>`).join(' · ');
  if (start) load(start);
}
init();
