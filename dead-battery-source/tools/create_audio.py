"""New performances and mathematically synthesized machinery, movement, and tool sounds."""
import asyncio,json,os,subprocess,wave
from pathlib import Path
import numpy as np
import edge_tts
from scipy.signal import butter,sosfilt
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/audio';SR=24000
V={'STEVE':('en-US-GuyNeural','-8%','-3Hz'),'MS. ELLIS':('en-GB-SoniaNeural','-12%','+7Hz'),'OLEG':('en-GB-RyanNeural','-10%','-7Hz'),'MERIDIAN':('en-US-AriaNeural','-7%','-6Hz')}
rng=np.random.default_rng(1933)
def save(name,values):
 values=np.nan_to_num(values);values/=max(1,np.max(np.abs(values))/.9)
 wav=OUT/(name+'.wav')
 with wave.open(str(wav),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes((values*32767).astype('<i2').tobytes())
 subprocess.run(['ffmpeg','-loglevel','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','5',str(OUT/(name+'.ogg'))],check=True)
 wav.unlink()
def filtered_noise(seconds,cutoff):
 n=rng.normal(0,1,int(SR*seconds));return sosfilt(butter(2,cutoff,fs=SR,output='sos'),n)
for name,freq,cut in [('step_concrete',155,3600),('step_vinyl',91,2700)]:
 t=np.arange(int(SR*.23))/SR
 pulse=np.exp(-t*35)+.55*np.exp(-np.maximum(0,t-.038)*65)*(t>.038)
 sound=filtered_noise(.23,cut)*pulse*.29+np.sin(2*np.pi*freq*t)*np.exp(-t*42)*.13
 sound[int(SR*.09):]+=.09*sound[:-int(SR*.09)]
 save(name,sound)
for name,freq in [('driver',180),('clip',490),('relay',112),('fuse',340)]:
 t=np.arange(int(SR*.34))/SR;env=np.exp(-t*25)
 save(name,filtered_noise(.34,2900)*env*.18+np.sin(2*np.pi*freq*t)*env*.09)
t=np.arange(SR*8)/SR
save('drone',(.065*np.sin(2*np.pi*114*t+2*np.sin(2*np.pi*1.1*t))+.022*np.sin(2*np.pi*342*t)+filtered_noise(8,4100)*.025)*(1+.12*np.sin(2*np.pi*.5*t)))
save('ventilation',filtered_noise(8,900)*.026+.014*np.sin(2*np.pi*50*t)+.008*np.sin(2*np.pi*150*t))
save('fan',filtered_noise(8,4600)*.06+.024*np.sin(2*np.pi*93*t))
arrival=[
 ('OLEG','Your badge is for night maintenance. Enter through the loading bay.','alley'),
 ('STEVE','Underpaid and underestimated. Perfect.','alley'),
 ('OLEG','Security feed zero seven. Keep the watchdog powered. Seat the bridge on a green diagnostic pulse.','power'),
 ('STEVE','Nobody reads the maintenance manual until something starts going bang.','alley'),
 ('OLEG','The chiller is down. Spare fuses are in the power room. Check the rating. I am not paying for a second Steve.','power'),
 ('STEVE','Give me a meter and some quiet.','alley'),
 ('OLEG','Copy the archive before destroying the root key. Your encrypted drive is in the kit.','archive'),
 ('STEVE','Backup first. Then the battery.','alley')]
hints={
 'camera_loop':('OLEG','You have given security a recording of itself. Nice trick.'),
 'pump_online':('STEVE','Six point three amps. Protective equipment with an actual job.'),
 'cooling_ready':('OLEG','The thermal interlock is green. The archive is in the east office.'),
 'copy_ready':('STEVE','There she is. Ms. Ellis, page seven. This one is coming with me.'),
 'key_down':('MERIDIAN','Signing key invalid. Emergency security restored.'),
 'escape':('OLEG','Roof hatch. West maintenance bay. They know. Keep your light off.'),
 'wrong_fuse':('STEVE','That rating is wrong. Protect the motor, not the inventory.'),
 'ellisbios':('STEVE','Twenty twenty six. Not bad for something they wanted to throw away.')}
async def main():
 data=json.loads((ROOT/'assets/dialogue.json').read_text());sem=asyncio.Semaphore(4)
 async def speak(fid,speaker,words,shot):
  path=OUT/(fid+'.ogg')
  async with sem:
   if not path.exists():
    voice,rate,pitch=V[speaker]
    for attempt in range(3):
     try:
      mp3=OUT/(fid+'.mp3')
      await edge_tts.Communicate(words,voice,rate=rate,pitch=pitch,proxy=os.environ.get('HTTPS_PROXY')).save(str(mp3))
      subprocess.run(['ffmpeg','-loglevel','error','-y','-i',str(mp3),'-c:a','libvorbis','-q:a','5',str(path)],check=True);mp3.unlink();break
     except Exception:
      if attempt==2:raise
   duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(path)]).decode().strip())
   print('New performance',fid,speaker,round(duration,2),flush=True)
   return {'speaker':speaker,'text':words,'audio':fid,'shot':shot,'duration':duration}
 data['core'][3]=await speak('fps_core_backup','STEVE',"Those are people's lives. The backup is safe. Now we take the key down.",'steve')
 data['arrival']=await asyncio.gather(*[speak('fps_arrival_'+str(i),*line) for i,line in enumerate(arrival)])
 keys=list(hints);lines=await asyncio.gather(*[speak('fps_'+k,*hints[k],'phone') for k in keys])
 data['hints']=dict(zip(keys,lines))
 (ROOT/'assets/dialogue.json').write_text(json.dumps(data,indent=2))
 print('First-person sound design finished.',flush=True)
asyncio.run(main())
