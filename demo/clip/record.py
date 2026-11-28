import asyncio, json, time
from playwright.async_api import async_playwright

ORIG = '0x47e8725c9a53b2917922c3db5bfac3dfd6743e0889a54fb8c84f73bf2878e1c4'
SPEED = '0xe96a136211ad81d8e19bab1858e763eda87ef564a67553128bc4d57660a01e80'
BLOB = 'f0vP2hOST23DjxJ0yCv77GqFIC7jkeQOOyBSXVgXxPY'
DEMO = 'https://codecustard.github.io/continuum/demo/'

CAPTION_JS = """
window.__cap = (t) => {
  let el = document.getElementById('__cap');
  if (!el) {
    el = document.createElement('div'); el.id = '__cap';
    el.style.cssText = 'position:fixed;left:0;right:0;bottom:0;z-index:2147483647;padding:14px 40px 16px;background:rgba(10,10,12,.86);color:#fff;font:600 24px/1.3 system-ui,-apple-system,Segoe UI,sans-serif;text-align:center;pointer-events:none';
    document.documentElement.appendChild(el);
  }
  el.textContent = t;
};
"""
# Signs with the testnet deploy key through a local signer (no wallet UI is shown or imitated).
WALLET_JS = """
(() => {
  const wallet = {
    version: '1.0.0', name: 'Testnet deploy key', icon: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg"/>', chains: ['sui:testnet'], accounts: [],
    features: {
      'standard:connect': { version: '1.0.0', connect: async () => { const a = await (await fetch('http://localhost:8766/addr')).text();
        wallet.accounts = [{ address: a, publicKey: new Uint8Array(32), chains: ['sui:testnet'], features: ['sui:signAndExecuteTransaction'] }]; return { accounts: wallet.accounts }; } },
      'standard:events': { version: '1.0.0', on: () => () => {} },
      'sui:signAndExecuteTransaction': { version: '2.0.0', signAndExecuteTransaction: async ({ transaction }) => {
        const r = await fetch('http://localhost:8766/', { method: 'POST', body: await transaction.toJSON() });
        if (!r.ok) throw new Error(await r.text()); const j = await r.json(); window.__digest = j.digest; return { digest: j.digest, bytes: '', signature: '', effects: '' }; } },
    },
  };
  const cb = ({ register }) => register(wallet);
  window.addEventListener('wallet-standard:app-ready', (e) => cb(e.detail));
  try { window.dispatchEvent(new CustomEvent('wallet-standard:register-wallet', { detail: cb })); } catch {}
})();
"""

marks = []
T0 = None
def mark(name):
    marks.append({'name': name, 't': time.monotonic() - T0})
    print(f'{marks[-1]["t"]:7.2f} {name}', flush=True)

async def cap(pg, text):
    await pg.evaluate('t => window.__cap(t)', text)

async def main():
    global T0
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
        ctx = await b.new_context(viewport={'width': 1280, 'height': 720}, record_video_dir='/tmp/clip/raw', record_video_size={'width': 1280, 'height': 720})
        T0 = time.monotonic()
        await ctx.add_init_script(CAPTION_JS)
        await ctx.add_init_script(WALLET_JS)
        pg = await ctx.new_page()

        # 1. Every One Counts loads the run from its Walrus record
        await pg.goto(f'https://ones.suikoi.life/?walrus={BLOB}')
        await pg.wait_for_url('**/?run=*', timeout=30000)
        await pg.wait_for_selector('text=PLAY NOW', timeout=30000)
        await cap(pg, 'Every One Counts: the run "Block Party", loaded from its record on Walrus')
        await pg.wait_for_timeout(1500); mark('s1')
        await pg.wait_for_timeout(9000); mark('s1e')

        # 2. The same run, recorded on Sui as a ContentRef
        await pg.goto(f'https://suiscan.xyz/testnet/object/{ORIG}')
        await pg.wait_for_selector('text=Object ID', timeout=40000)
        await pg.wait_for_timeout(2500)
        try:
            await pg.click('text=Fields', timeout=5000); await pg.wait_for_timeout(2500)
        except Exception as e:
            print('fields tab', e)
        await cap(pg, 'Recorded on Sui testnet as a ContentRef: game, author, Walrus blob ID')
        await pg.wait_for_timeout(1000); mark('s2')
        await pg.mouse.wheel(0, 300); await pg.wait_for_timeout(8000); mark('s2e')

        # 3. A second game reads it from Sui and draws it its own way
        await pg.goto(f'{DEMO}?ref={ORIG}')
        await pg.wait_for_selector('text=2 · Lineage on Sui', timeout=40000)
        await cap(pg, 'A second game reads the ContentRef from Sui and draws the run its own way')
        await pg.wait_for_timeout(1500); mark('s3')
        await pg.mouse.wheel(0, 260); await pg.wait_for_timeout(9500); mark('s3e')

        # 4. Remix it (from the Speedrun remix, so the chain grows to four)
        await pg.goto(f'{DEMO}?ref={SPEED}')
        await pg.wait_for_selector('[data-twist="rush"]', timeout=40000)
        await pg.evaluate("document.querySelector('[data-twist]').scrollIntoView({block:'center'})")
        await cap(pg, 'Remix it: the new record goes to Walrus, the remix is signed with a testnet key')
        await pg.wait_for_timeout(2500); mark('s4')
        await pg.click('[data-twist="rush"]'); mark('s4click')
        await pg.wait_for_selector('#status.done', timeout=120000); mark('s4done')
        await pg.evaluate("window.scrollTo(0,0)")
        await cap(pg, 'Published: a new ContentRef on Sui testnet')
        await pg.wait_for_timeout(4000); mark('s4e')
        new_id = await pg.input_value('#refId')
        digest = await pg.evaluate('window.__digest')

        # 5. Lineage: verified by provenance::derive, then the real transaction
        await pg.evaluate("document.querySelector('.chain').scrollIntoView({block:'start'}); window.scrollBy(0,-60)")
        await cap(pg, 'Lineage on Sui: every link verified by provenance::derive, not claimed')
        await pg.wait_for_timeout(1000); mark('s5')
        await pg.wait_for_timeout(6500); mark('s5e')
        await pg.goto(f'https://suiscan.xyz/testnet/tx/{digest}')
        await pg.wait_for_timeout(9000)
        await cap(pg, f'The remix transaction on Suiscan (testnet): {digest[:10]}…')
        await pg.wait_for_timeout(1000); mark('s5b')
        await pg.wait_for_timeout(6000); mark('s5be')

        # 6. End card
        await pg.goto('file:///tmp/clip/endcard.html')
        await pg.wait_for_timeout(2500); mark('s6')
        await pg.wait_for_timeout(8500); mark('s6e')

        await ctx.close(); await b.close()
        json.dump({'marks': marks, 'new_id': new_id, 'digest': digest}, open('/tmp/clip/marks.json', 'w'), indent=1)
        print('new', new_id, digest)

asyncio.run(main())
