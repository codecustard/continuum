import asyncio, json, time
from playwright.async_api import async_playwright
exec(open('/tmp/clip/record.py').read().split('marks = []')[0].split('CAPTION_JS = ')[0])
CAPTION_JS = open('/tmp/clip/record.py').read().split('CAPTION_JS = """')[1].split('"""')[0]
ORIG = '0x47e8725c9a53b2917922c3db5bfac3dfd6743e0889a54fb8c84f73bf2878e1c4'
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
        ctx = await b.new_context(viewport={'width':1280,'height':720}, record_video_dir='/tmp/clip/raw2', record_video_size={'width':1280,'height':720})
        T0=time.monotonic()
        await ctx.add_init_script(CAPTION_JS)
        pg = await ctx.new_page()
        await pg.goto(f'https://suiscan.xyz/testnet/object/{ORIG}')
        await pg.wait_for_selector('text=Object ID', timeout=40000)
        await pg.wait_for_timeout(2500)
        await pg.click('text=Fields'); await pg.wait_for_timeout(2500)
        labels = await pg.eval_on_selector_all('div, span', "els => els.filter(e=>e.children.length===0).map(e=>e.innerText.trim()).filter(t=>/^(Game|Kind|Blob Id|Blob_id|blob_id|Author|Name|Parent|Publisher)/i.test(t)).slice(0,20)")
        print(labels)
        # center the fields block
        await pg.evaluate("""() => { const el=[...document.querySelectorAll('div,span')].find(e=>e.children.length===0 && /^Author$/i.test(e.innerText.trim())); if(el){ el.scrollIntoView({block:'center'}); window.scrollBy(0,40);} }""")
        await pg.evaluate("t => window.__cap(t)", 'Recorded on Sui testnet as a ContentRef: game, author, Walrus blob ID')
        await pg.wait_for_timeout(1000); t1=time.monotonic()-T0
        await pg.wait_for_timeout(8000); t2=time.monotonic()-T0
        await pg.screenshot(path='/tmp/clip/s2.png')
        await ctx.close(); await b.close()
        print(t1,t2)
asyncio.run(main())
