"""Verify preferences and progress survive an immediate browser reload."""
import asyncio
import json
import os
import sys
from urllib.parse import urlsplit
from playwright.async_api import async_playwright

URL = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:8080/'

async def check(page, expression, timeout=90000):
    await page.wait_for_function('(s)=>{let x=window.steveState; return x && ('+expression+');}', timeout=timeout)
    return await page.evaluate('window.steveState')

async def button(page, prefix):
    current = await check(page, 'x.controls.some(b=>b.text.startsWith('+json.dumps(prefix)+') && !b.disabled)')
    control = next(b for b in current['controls'] if b['text'].startswith(prefix) and not b['disabled'])
    vw, vh = current['viewport']
    size = page.viewport_size
    await page.mouse.click(control['x'] * size['width'] / vw, control['y'] * size['height'] / vh)

async def main():
    async with async_playwright() as p:
        launch = {'executable_path':'/usr/bin/chromium','headless':True,'args':['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']}
        proxy_url = os.environ.get('HTTPS_PROXY')
        if proxy_url and URL.startswith('https:'):
            parsed = urlsplit(proxy_url)
            proxy = {'server': f'{parsed.scheme}://{parsed.hostname}:{parsed.port}', 'bypass':'localhost,127.0.0.1'}
            if parsed.username:
                proxy.update(username=parsed.username,password=parsed.password or '')
            launch['proxy'] = proxy
        browser = await p.chromium.launch(**launch)
        page = await browser.new_page(viewport={'width':960,'height':600},device_scale_factor=1,ignore_https_errors=True)
        errors, failed = [], []
        page.on('pageerror',lambda error:errors.append(str(error)))
        page.on('console',lambda message:errors.append(message.text) if message.type=='error' or 'SCRIPT ERROR' in message.text else None)
        page.on('requestfailed',lambda request:failed.append(request.url))
        try:
            response = await page.goto(URL,wait_until='domcontentloaded',timeout=90000)
            assert response.status == 200
            await check(page,'x.ready && x.state==="title"')
            print('PASS WebGL game loads',flush=True)
            await page.keyboard.press('Escape')
            await button(page,'MUSIC / ON')
            await check(page,'x.controls.some(b=>b.text==="MUSIC / OFF")')
            await button(page,'VOICES / ON')
            await check(page,'x.controls.some(b=>b.text==="VOICES / OFF")')
            saved = await page.evaluate("JSON.parse(localStorage.getItem('steve.dead_battery.shift.v1'))")
            assert saved['music'] is False and saved['voices'] is False, saved
            print('PASS both preferences saved immediately',flush=True)
            # Reload as soon as the button change is acknowledged, without a flush delay.
            await page.reload(wait_until='domcontentloaded',timeout=90000)
            await check(page,'x.ready && x.state==="title"')
            await button(page,'CONTINUE YOUR SHIFT')
            await check(page,'x.state==="shop" && x.step===0')
            await page.keyboard.press('Escape')
            await check(page,'x.panel && x.controls.some(b=>b.text==="VOICES / OFF") && x.controls.some(b=>b.text==="MUSIC / OFF")')
            print('PASS immediate reload retains preferences and resumes progress',flush=True)
            assert not errors,errors
            assert not failed,failed
            print('PASS no runtime errors or failed asset requests',flush=True)
        except Exception:
            print('LAST STATE',json.dumps(await page.evaluate('window.steveState')),flush=True)
            print('ERRORS',json.dumps(errors),flush=True)
            raise
        finally:
            await browser.close()

asyncio.run(main())
