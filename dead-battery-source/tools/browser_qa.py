"""Browser input and rendering checks. Fixtures come from the native full-mission traversal.
No runtime setters: gameplay is driven through browser keyboard, mouse and CDP touch events.
"""
import asyncio,ast,json,math,os
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs';URL=os.environ.get('STEVE_TEST_URL','http://127.0.0.1:8081/')
AUDIO_PROBE=''
old=Path('/tmp/steve_public_smoke.py')
if old.exists():
 for n in ast.parse(old.read_text()).body:
  if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='AUDIO_PROBE' for t in n.targets):AUDIO_PROBE=ast.literal_eval(n.value)
report=[]
def record(message):report.append(message);print(message,flush=True)
async def state(page):return await page.evaluate('window.steveState')
async def check(page,condition,timeout=120000):
 await page.wait_for_function('(x)=>window.steveState && ('+condition.replace('s.','window.steveState.')+')',timeout=timeout)
 return await state(page)
class Game:
 def __init__(self,page,mobile=False):self.page=page;self.mobile=mobile;self.cdp=None;self.points={};self.mx=400;self.my=225;self.gain=.0024
 async def init(self):self.cdp=await self.page.context.new_cdp_session(self.page)
 async def send(self,kind):await self.cdp.send('Input.dispatchTouchEvent',{'type':kind,'touchPoints':[{'id':i,'x':p[0],'y':p[1],'radiusX':3,'radiusY':3,'force':1} for i,p in self.points.items()]})
 async def down(self,i,x,y):self.points[i]=(x,y);await self.send('touchStart')
 async def move(self,i,x,y):self.points[i]=(x,y);await self.send('touchMove')
 async def up(self,i):self.points.pop(i,None);await self.send('touchEnd')
 async def button(self,text):
  s=await state(self.page);b=next(b for b in s['controls'] if b['text'].startswith(text));v=self.page.viewport_size;x=b['x']*v['width']/s['viewport'][0];y=b['y']*v['height']/s['viewport'][1]
  if self.mobile:await self.down(7,x,y);await asyncio.sleep(.12);await self.up(7)
  else:await self.page.mouse.click(x,y)
  await asyncio.sleep(.4)
 async def swipe(self,dx,dy,i=1):
  v=self.page.viewport_size;x=v['width']*.72;y=v['height']*.36
  await self.down(i,x,y)
  for k in range(1,5):await self.move(i,x+dx*k/4,y+dy*k/4);await asyncio.sleep(.035)
  await self.up(i);await asyncio.sleep(.35)
 async def calibrate(self):
  if self.mobile:
   s=await state(self.page);await self.swipe(30,0);t=await state(self.page);change=(t['yaw']-s['yaw']+math.pi)%(2*math.pi)-math.pi;self.gain=abs(change/30)
  else:
   await self.page.mouse.move(self.mx,self.my);await self.page.mouse.down(button='right');await asyncio.sleep(.35);s=await state(self.page);self.mx+=30;await self.page.mouse.move(self.mx,self.my);await asyncio.sleep(.5);t=await state(self.page);change=(t['yaw']-s['yaw']+math.pi)%(2*math.pi)-math.pi;self.gain=abs(change/30)
  assert self.gain>.0001,(self.gain,s,t)
  record('PASS actual '+('touch swipe' if self.mobile else 'mouse drag')+' changes first-person yaw / gain %.5f'%self.gain)
 async def aim(self,id):
  for _ in range(14):
   s=await state(self.page)
   if s['focus']==id:return
   t=s['targets'][id]['p'];e=s['eye'];dx=t[0]-e[0];dy=t[1]-e[1];dz=t[2]-e[2];yaw=math.atan2(-dx,-dz);pitch=math.atan2(dy,math.hypot(dx,dz));dyaw=(yaw-s['yaw']+math.pi)%(2*math.pi)-math.pi;dpitch=pitch-s['pitch']
   px=max(-100,min(100,-dyaw/self.gain));py=max(-100,min(100,-dpitch/self.gain))
   if self.mobile:await self.swipe(px,py)
   else:self.mx+=px;self.my+=py;await self.page.mouse.move(self.mx,self.my);await asyncio.sleep(.4)
  raise AssertionError('Aim failed '+id+' '+json.dumps(await state(self.page)))
 async def use(self,id,expected):
  await self.aim(id);s=await state(self.page);duration=s['targets'][id]['duration']
  if math.dist(s['eye'],s['targets'][id]['p'])>1.58 and not self.mobile:
   await self.page.keyboard.down('w')
   try:
    await self.page.wait_for_function('(id)=>{const s=window.steveState;return Math.hypot(...s.eye.map((v,i)=>v-s.targets[id].p[i]))<1.45;}',arg=id,timeout=20000)
   finally:await self.page.keyboard.up('w')
   await self.aim(id);s=await state(self.page)
   record('PASS first-person keyboard movement approaches '+id)
  if self.mobile:
   b=next(b for b in s['controls'] if b['text']=='ACT');v=self.page.viewport_size;await self.down(3,b['x']*v['width']/s['viewport'][0],b['y']*v['height']/s['viewport'][1])
  else:await self.page.keyboard.down('e')
  await check(self.page,expected)
  if self.mobile:await self.up(3)
  else:await self.page.keyboard.up('e')
  record('PASS '+('touch ACT' if self.mobile else 'keyboard E')+' performs '+id)
 async def shot(self,name):
  await self.page.screenshot(path=str(OUT/(name+'.png')),timeout=120000)
  s=await state(self.page);record('FRAME '+name+' / '+s['state']+' / '+str(s.get('fps'))+' FPS on software GPU')
async def launch_case(browser,fixture,mobile=False,landscape=False):
 viewport={'width':844,'height':390} if landscape else ({'width':390,'height':844} if mobile else {'width':800,'height':450})
 c=await browser.new_context(viewport=viewport,device_scale_factor=1,is_mobile=mobile,has_touch=mobile)
 if fixture:
  saved=json.loads((OUT/('fixture_'+fixture+'.json')).read_text())
  await c.add_init_script('localStorage.setItem("steve.dead_battery.first_person.v2",'+json.dumps(json.dumps(saved))+');')
 else:await c.add_init_script('localStorage.removeItem("steve.dead_battery.first_person.v2");')
 if AUDIO_PROBE:await c.add_init_script(AUDIO_PROBE)
 page=await c.new_page();logs=[]
 page.on('console',lambda m:logs.append(m.type+': '+m.text) or (OUT/'qa-browser-console.log').write_text('\n'.join(logs)))
 page.on('pageerror',lambda e:logs.append('PAGE ERROR: '+str(e)))
 await page.goto(URL,wait_until='domcontentloaded',timeout=90000);await check(page,'s.ready && s.state==="title"',180000)
 g=Game(page,mobile);await g.init();await g.button('CONTINUE YOUR SHIFT' if fixture else 'START YOUR SHIFT');await check(page,'s.state!=="title"');return c,g,logs
async def main():
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage'])
  try:
   if not os.environ.get('STEVE_QA_SCENES_ONLY'):
    c,g,logs=await launch_case(browser,'pc_open')
    await g.calibrate();await g.page.keyboard.press('3');await check(g.page,'s.tool===3');await g.use('pc_clip','s.repair===5');await g.page.keyboard.press('0');await check(g.page,'s.tool===0');await g.use('pc_cell','s.repair===6');await g.shot('desktop-board-repair');await g.use('pc_panel','s.repair===7');assert not any('SCRIPT ERROR' in l or 'PAGE ERROR' in l for l in logs),logs;await c.close()
    c,g,logs=await launch_case(browser,'pc_open',True)
    s=await state(g.page);assert any(b['text']=='ACT' for b in s['controls']);await g.calibrate()
    # Two simultaneous fingers: left movement plus a right-side look swipe.
    v=g.page.viewport_size;vw,vh=s['viewport'];sx=84*v['width']/vw;sy=(vh-191)*v['height']/vh
    before=await state(g.page);await g.down(0,sx,sy);await g.move(0,sx,sy-22);await g.down(1,280,310);await g.move(1,300,313);await asyncio.sleep(.7);await g.up(1);await g.up(0);after=await state(g.page)
    assert math.dist(before['position'],after['position'])>.035,(before,after)
    assert abs(before['yaw']-after['yaw'])>.02,(before,after);record('PASS mobile movement and looking work with simultaneous independent fingers')
    await g.button('DUCK');await check(g.page,'s.crouched');await g.button('STAND');await check(g.page,'!s.crouched')
    await g.button('TOOLS');await check(g.page,'s.panel');await g.button('3 / PRECISION PICK');await check(g.page,'s.tool===3 && !s.panel')
    await g.use('pc_clip','s.repair===5');await g.button('TOOLS');await check(g.page,'s.panel');await g.button('0 / HANDS');await check(g.page,'s.tool===0 && !s.panel');await g.use('pc_cell','s.repair===6');await g.shot('mobile-portrait-repair')
    await g.page.set_viewport_size({'width':844,'height':390});await asyncio.sleep(1.5);await g.shot('mobile-landscape-repair');s=await state(g.page);b=next(b for b in s['controls'] if b['text']=='ACT');assert b['width']*844/s['viewport'][0]>=44;await g.button('TOOLS');await check(g.page,'s.panel');await g.button('2 / MULTIMETER');await check(g.page,'s.tool===2 && !s.panel');record('PASS landscape tool selection and minimum 44-pixel action target')
    assert not any('SCRIPT ERROR' in l or 'PAGE ERROR' in l for l in logs),logs;await c.close()
   c,g,logs=await launch_case(browser,'repaired')
   await g.calibrate();await g.use('pc_bios','s.state==="opening"');await g.shot('cinematic-ellis')
   if AUDIO_PROBE:
    await g.page.wait_for_function('window.steveAudioProbe.peak>.06',timeout=30000);record('PASS synthesized cinematic dialogue produces audible browser output')
   await g.button('NEXT LINE');await check(g.page,'s.line>=1');await g.shot('cinematic-dialogue');await g.button('SKIP SCENE');await check(g.page,'s.state==="shop"');await c.close()
   for fixture,frame in [('chiller','facility-chiller'),('core','facility-root-vault'),('roof','facility-rooftop')]:
    c,g,logs=await launch_case(browser,fixture);await g.page.keyboard.press('f');await asyncio.sleep(.6);await g.shot(frame);assert not any('SCRIPT ERROR' in l or 'PAGE ERROR' in l for l in logs),logs;await c.close()
   record('BROWSER QA PASS')
  finally:
   (OUT/'browser-validation.txt').write_text('\n'.join(report)+'\n');await browser.close()
asyncio.run(main())
