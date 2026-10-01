import asyncio,json,os
from playwright.async_api import async_playwright

async def main():
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage'])
  page=await browser.new_page(viewport={'width':1440,'height':900},device_scale_factor=1)
  logs=[]
  page.on('console',lambda m:logs.append(m.type+': '+m.text))
  page.on('pageerror',lambda e:logs.append('PAGEERROR: '+str(e)))
  await page.goto('http://127.0.0.1:8080',wait_until='networkidle',timeout=90000)
  try:
   await page.wait_for_function('window.steveState?.ready',timeout=60000)
  except Exception:
   print('BOOT LOG',json.dumps(logs),flush=True)
   print('STATUS',await page.locator('#status').inner_text(),flush=True)
   await page.screenshot(path='/workspace/steve-pc/docs/failed-boot.png')
   raise
  await page.wait_for_timeout(3000)
  await page.screenshot(path='/workspace/steve-pc/docs/title.png')
  print('STATE',await page.evaluate('window.steveState'),flush=True)
  await page.mouse.click(260,603)
  await page.wait_for_timeout(3500)
  await page.screenshot(path='/workspace/steve-pc/docs/opening.png')
  print('AFTER START',await page.evaluate('window.steveState'),flush=True)
  await page.mouse.click(1360,34)
  await page.wait_for_timeout(3500)
  await page.screenshot(path='/workspace/steve-pc/docs/shop.png')
  print('AFTER SKIP',await page.evaluate('window.steveState'),flush=True)
  print('BROWSER LOG',json.dumps(logs),flush=True)
  await browser.close()
asyncio.run(main())
