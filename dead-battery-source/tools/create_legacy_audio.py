"""New dialogue performances plus entirely synthesized score and effects."""
import asyncio, json, os, wave, subprocess
import numpy as np
import edge_tts
R=os.path.dirname(os.path.dirname(os.path.abspath(__file__)));OUT=R+'/assets/audio';SR=24000
VOICE={'STEVE':('en-US-GuyNeural','-8%','-3Hz'),'MS. ELLIS':('en-GB-SoniaNeural','-12%','+7Hz'),'OLEG':('en-GB-RyanNeural','-10%','-7Hz'),'MERIDIAN':('en-US-AriaNeural','-7%','-6Hz')}
SCENES={
 'opening':[
  ['STEVE','One battery. Two pounds. And your clock is yours again.','counter'],
  ['MS. ELLIS','The other shop said I needed a new computer. This one has Arthur\'s letters on it.','ellis'],
  ['STEVE','Then this is the right computer. I made you a second copy, too.','steve'],
  ['MS. ELLIS','Ninety-three years old, and I finally meet an honest repair man.','ellis'],
  ['STEVE','Don\'t tell anyone. Terrible for business.','chime'],
  ['STEVE','I\'ll be right with you, Mr. Thomas.','oleg_enter'],
  ['MS. ELLIS','Give that cat a biscuit from me. And get some sleep, Steven.','escort'],
  ['STEVE','Yes, ma\'am. See you next Thursday.','car'],
  ['OLEG','Mr. Thomas?','return'],
  ['STEVE','You\'re wearing sunglasses in a computer shop, Oleg. I had to give you something ordinary.','steve'],
  ['OLEG','Tallinn. Meridian. An asset called the Widowmaker. Eight million pension records. An auction at midnight.','case'],
  ['STEVE','Someone found a way to steal from people who can\'t fight back.','steve'],
  ['OLEG','Destroy the root signing key. The operation dies with it. First class. A service identity. And your usual tools.','case'],
  ['STEVE','One hundred percent up front.','steve'],
  ['OLEG','Already paid.','oleg'],
  ['STEVE','Good. The cat sitter charges by the hour.','wide']
 ],
 'arrival':[
  ['OLEG','Meridian sublevel eight. Your badge says night maintenance. Try to look underpaid.','vault'],
  ['STEVE','I run a repair shop. I\'ve been rehearsing all my life.','steve'],
  ['OLEG','Security uses a closed circuit. Coolant, access, then the core. In that order.','vault'],
  ['STEVE','And the cameras?','steve'],
  ['OLEG','A patrol drone. Keep out of the red cone. That cart has a spare identity.','cart'],
  ['STEVE','All right. Let\'s fix somebody\'s very expensive mistake.','wide']
 ],
 'core':[
  ['MERIDIAN','Unauthorized technician. Your warranty is void.','core'],
  ['STEVE','Story of my life.','steve'],
  ['OLEG','There is your asset. Take the key down and leave.','core'],
  ['STEVE','Those are people\'s lives in there. I\'m taking a backup first.','steve'],
  ['MERIDIAN','You cannot repair what you do not understand.','core'],
  ['STEVE','I understand a dead battery when I see one.','wide']
 ],
 'ending':[
  ['OLEG','The auction is gone. Every account frozen. You were asked to destroy the key.','end'],
  ['STEVE','I did. And sent the records to the people who can return the money.','steve'],
  ['OLEG','That was not in the brief.','oleg'],
  ['STEVE','Neither was the part where Ms. Ellis was on page seven.','steve'],
  ['OLEG','You always make it personal.','oleg'],
  ['STEVE','No. I make it work.','cat'],
  ['MS. ELLIS','Steven? It\'s me. My bank called. Something wonderful has happened.','phone'],
  ['STEVE','Glad to hear it, Ms. Ellis. Bring the computer in Thursday. We\'ll give it a clean.','wide']
 ]}
os.makedirs(OUT,exist_ok=True)
def save(name,a):
 a=np.nan_to_num(a);peak=max(.01,float(np.max(np.abs(a))));a=a/max(1,peak/0.93)
 with wave.open(OUT+'/'+name+'.wav','w') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes((a*32767).astype('<i2').tobytes())
 subprocess.run(['ffmpeg','-loglevel','error','-y','-i',OUT+'/'+name+'.wav','-c:a','libvorbis','-q:a','4',OUT+'/'+name+'.ogg'],check=True)
 os.remove(OUT+'/'+name+'.wav')
def tone(f,d=.4):
 t=np.arange(int(d*SR))/SR;return np.sin(math_tau*f*t)*np.minimum(1,t/.005)*np.minimum(1,(d-t)/.04)
math_tau=2*np.pi
rng=np.random.default_rng(98)
save('chime',np.concatenate([tone(1046,.23)*.19,tone(1318,.45)*.16]))
save('click',tone(810,.065)*.12)
save('success',np.concatenate([tone(f,.13)*.16 for f in [523,659,784,1046]]))
save('error',tone(156,.22)*.17)
save('footstep',(rng.normal(0,.15,int(SR*.09))*np.exp(-np.arange(int(SR*.09))/SR*54)))
save('pet',tone(112,.7)*.08+tone(116,.7)*.075)
save('door',np.concatenate([rng.normal(0,.03,SR//3),tone(94,.15)*.11]))
save('alarm',np.concatenate([tone(660,.19)*.12,tone(520,.19)*.12]))
save('shutdown',np.concatenate([tone(f,.15)*.14 for f in [784,659,523,262,130]]))
# Original 48-second slow electronic score: harmonically sequenced, no samples.
for name,is_vault in [('shop_ambience',False),('vault_ambience',True)]:
 d=48;n=d*SR;t=np.arange(n)/SR;out=np.zeros(n)
 progression=[(110,130.813,164.814),(98,123.471,146.832),(87.307,110,130.813),(98,130.813,164.814)]
 for i,chord in enumerate(progression*2):
  st=i*6;tt=np.arange(SR*6)/SR;env=np.sin(np.pi*tt/6)**.7
  for f in chord:
   out[st*SR:(st+6)*SR]+=env*(np.sin(math_tau*f*tt)+.18*np.sin(math_tau*f*2*tt))*.026
  for k in range(8):
   at=st+k*.75;freq=chord[k%3]*(4 if is_vault else 2);ln=SR//2;tx=np.arange(ln)/SR
   out[int(at*SR):int(at*SR)+ln]+=(np.sin(math_tau*freq*tx)+.3*np.sin(math_tau*freq*3*tx))*np.exp(-tx*9)*.058
 if is_vault:
  out+=.017*np.sin(math_tau*55*t)*(1+.2*np.sin(math_tau*.12*t))
  for at in np.arange(0,48,.75):
   ln=SR//5;tx=np.arange(ln)/SR;kick=np.sin(math_tau*(43*tx+30*(1-np.exp(-tx*18))/18))*np.exp(-tx*17)*.07
   out[int(at*SR):int(at*SR)+ln]+=kick
 out*=np.minimum(1,t/1.5)*np.minimum(1,(48-t)/1.5)
 save(name,out)

async def main():
 sem=asyncio.Semaphore(4)
 async def speak(scene,i,line):
  speaker,words,shot=line;fid=scene+'_'+str(i).zfill(2);path=OUT+'/'+fid+'.ogg'
  async with sem:
   if not os.path.exists(path):
    voice,rate,pitch=VOICE[speaker]
    for attempt in range(3):
     try:
      await edge_tts.Communicate(words,voice,rate=rate,pitch=pitch,proxy=os.environ.get('HTTPS_PROXY')).save(OUT+'/'+fid+'.mp3')
      subprocess.run(['ffmpeg','-loglevel','error','-y','-i',OUT+'/'+fid+'.mp3','-c:a','libvorbis','-q:a','4',path],check=True)
      os.remove(OUT+'/'+fid+'.mp3');break
     except Exception:
      if attempt==2:raise
   duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',path]).decode().strip())
   print('Voice',fid,speaker,round(duration,1),flush=True)
   return {'speaker':speaker,'text':words,'shot':shot,'audio':fid,'duration':duration}
 data={}
 for scene,lines in SCENES.items():data[scene]=await asyncio.gather(*[speak(scene,i,l) for i,l in enumerate(lines)])
 with open(R+'/assets/dialogue.json','w') as f:json.dump(data,f,indent=2)
 print('Original sound and voices complete',flush=True)
asyncio.run(main())
