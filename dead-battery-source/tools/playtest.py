"""End-to-end checks against the actual browser export using visible UI inputs."""
import asyncio,json,math
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path('/workspace/steve-pc')
async def state(page):return await page.evaluate('window.steveState')
async def check(page,predicate,timeout=120000):
 await page.wait_for_function('(s)=>{let x=window.steveState; return x && ('+predicate+');}',timeout=timeout)
 return await state(page)
async def button(page,name,index=0):
 await check(page,'x.controls.some(b=>b.text.startsWith('+json.dumps(name)+') && !b.disabled)')
 s=await state(page)
 b=[b for b in s['controls'] if b['text'].startswith(name) and not b['disabled']][index]
 vw,vh=s['viewport'];pw,ph=page.viewport_size.values()
 await page.mouse.click(b['x']*pw/vw,b['y']*ph/vh)
 await page.wait_for_timeout(650)
async def marker(page,id):
 await page.wait_for_timeout(2300)
 s=await state(page);x,y=s['markers'][id];vw,vh=s['viewport'];pw,ph=page.viewport_size.values()
 await page.mouse.click(x*pw/vw,y*ph/vh)
 previous=s
 await check(page,'x.nearest==='+json.dumps(id)+' || x.panel || !["shop","vault"].includes(x.state) || x.step>'+str(previous['step'])+' || x.case!=='+json.dumps(previous['case']),60000)
 s=await state(page)
 if s['nearest']==id and not s['panel'] and s['state'] in ['shop','vault']:
  await page.keyboard.press('KeyE')
  await page.wait_for_timeout(600)
async def shot(page,name):await page.screenshot(path=str(ROOT/'docs'/name))
async def desktop(browser):
 page=await browser.new_page(viewport={'width':960,'height':600},device_scale_factor=1)
 logs=[]
 page.on('console',lambda m:logs.append(m.type+': '+m.text))
 page.on('pageerror',lambda e:logs.append('PAGEERROR: '+str(e)))
 try:
  await page.goto('http://127.0.0.1:8080',wait_until='networkidle',timeout=90000)
  await check(page,'x.ready',90000)
  await page.wait_for_timeout(2000)
  await shot(page,'title-final.png')
  await button(page,'START THE NIGHT')
  await check(page,'x.state==="opening"')
  await page.wait_for_timeout(3000)
  await shot(page,'cinematic-final.png')
  await button(page,'SKIP SCENE')
  await check(page,'x.state==="shop"')
  print('CHECK briefcase',flush=True)
  await marker(page,'case')
  await check(page,'x.panel')
  await shot(page,'briefcase-final.png')
  await button(page,'TAKE THE JOB')
  await check(page,'x.case && !x.panel')
  print('PASS briefcase and navigation',flush=True)
  await marker(page,'cat')
  await check(page,'x.panel && x.secrets===1')
  await shot(page,'bios-final.png')
  await button(page,'BACK TO WORK')
  await marker(page,'door')
  await check(page,'x.state==="arrival"',60000)
  await page.wait_for_timeout(3000)
  await shot(page,'vault-arrival.png')
  await button(page,'SKIP SCENE')
  await check(page,'x.state==="vault"')
  await marker(page,'badge')
  await check(page,'x.step===1')
  print('PASS arrival and cover identity',flush=True)
  await marker(page,'security')
  await check(page,'x.panel',60000)
  s=await state(page);blank=[b for b in s['controls'] if b['text']=='']
  assert len(blank)==9,('Expected nine circuit tiles',s)
  for i,n in [(3,1),(4,2),(1,2),(2,3),(5,2)]:
   for j in range(n):
    b=blank[i];await page.mouse.click(b['x']*2/3,b['y']*2/3);await page.wait_for_timeout(150)
  await shot(page,'circuit-final.png')
  await button(page,'RUN DIAGNOSTIC')
  await check(page,'x.step===2 && !x.panel')
  print('PASS closed-circuit puzzle',flush=True)
  await marker(page,'coolant')
  await check(page,'x.panel',60000)
  s=await state(page);plus=[b for b in s['controls'] if b['text']=='+']
  assert len(plus)==3,('Expected valve controls',s)
  for i,n in enumerate([3,6,3]):
   for j in range(n):
    b=plus[i];await page.mouse.click(b['x']*2/3,b['y']*2/3);await page.wait_for_timeout(120)
  await shot(page,'coolant-final.png')
  await button(page,'STABILIZE COOLANT')
  await check(page,'x.step===3 && !x.panel')
  print('PASS coolant puzzle',flush=True)
  await marker(page,'core')
  await check(page,'x.state==="core"',60000)
  await page.wait_for_timeout(1500)
  await shot(page,'core-cinematic.png')
  await button(page,'SKIP SCENE')
  await check(page,'x.panel && x.state==="vault"')
  for text in ['01  /  COPY','02  /  ISOLATE','03  /  PULL']:await button(page,text)
  await check(page,'x.step===4 && !x.panel')
  print('PASS evidence and asset shutdown',flush=True)
  await marker(page,'lift')
  await check(page,'x.state==="ending"',60000)
  await page.wait_for_timeout(1500)
  await button(page,'SKIP SCENE')
  await check(page,'x.state==="results"')
  await shot(page,'results-final.png')
  print('PASS extraction and ending',await state(page),flush=True)
  await button(page,'RETURN TO THE SHOP')
  await check(page,'x.state==="shop" && !x.panel')
  await button(page,'II')
  await check(page,'x.panel')
  await button(page,'MUSIC /')
  await button(page,'BACK TO WORK')
  await page.reload(wait_until='networkidle')
  await check(page,'x.state==="title"')
  await button(page,'CONTINUE YOUR SHIFT')
  await check(page,'x.state==="shop" && x.secrets===1 && x.step===5')
  print('PASS save/resume and audio preference',flush=True)
  errors=[l for l in logs if 'SCRIPT ERROR' in l or 'PAGEERROR' in l or l.startswith('error:')]
  assert not errors,errors
  print('PASS no browser runtime errors',flush=True)
 except Exception:
  print('FAILED STATE',await state(page),flush=True)
  await shot(page,'playtest-failure.png')
  raise
 finally:
  (ROOT/'docs'/'playtest-console.json').write_text(json.dumps(logs,indent=2))
  await page.close()
async def mobile(browser):
 page=await browser.new_page(viewport={'width':390,'height':844},device_scale_factor=1,is_mobile=True,has_touch=True)
 try:
  await page.goto('http://127.0.0.1:8080',wait_until='networkidle',timeout=90000)
  await check(page,'x.ready',90000)
  await shot(page,'mobile-title.png')
  await button(page,'START THE NIGHT')
  await check(page,'x.state==="opening"')
  await page.keyboard.press('Space');await page.wait_for_timeout(1500)
  await shot(page,'mobile-subtitles.png')
  await button(page,'SKIP SCENE')
  await check(page,'x.state==="shop"')
  await shot(page,'mobile-shop.png')
  s=await state(page);before=s['position'];vw,vh=s['viewport'];pw,ph=390,844
  # Touch stick emulates a pointer drag in Godot's touch-compatible UI.
  cx,cy=80*pw/vw,(vh-90)*ph/vh
  await page.mouse.move(cx,cy);await page.mouse.down();await page.mouse.move(cx+30,cy)
  await page.wait_for_timeout(1000);await page.mouse.up();await page.wait_for_timeout(600)
  after=(await state(page))['position']
  assert math.dist(before,after)>.3,(before,after)
  await button(page,'CASE FILE')
  await check(page,'x.panel')
  await shot(page,'mobile-case-file.png')
  await button(page,'CLOSE CASE FILE')
  print('PASS phone title, subtitles, joystick, and journal',flush=True)
 finally:await page.close()
async def main():
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage'])
  try:await desktop(browser);await mobile(browser)
  finally:await browser.close()
asyncio.run(main())
