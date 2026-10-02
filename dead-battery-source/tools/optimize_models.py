"""Deduplicate our Blender-generated textures without changing any geometry or materials.
GLBs retain geometry and point to original, shared, project-relative PNGs.
"""
import json,struct,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SHARED=ROOT/'assets/textures/shared';SHARED.mkdir(exist_ok=True)
manifest_path=ROOT/'assets/textures/shared_manifest.json'
manifest=json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
for path in sorted((ROOT/'assets/models').glob('*.glb')):
 b=path.read_bytes();length=struct.unpack_from('<I',b,12)[0]
 d=json.loads(b[20:20+length]);bin_off=20+length
 blob=b[bin_off+8:];views=d.get('bufferViews',[]);image_views=set()
 for im in d.get('images',[]):
  if 'bufferView' not in im:
   name=Path(im.get('uri','')).name
   if name in manifest and path.name not in manifest[name]['models']:manifest[name]['models'].append(path.name)
   continue
  i=im['bufferView'];view=views[i];off=view.get('byteOffset',0);data=blob[off:off+view['byteLength']]
  sha=hashlib.sha256(data).hexdigest();name='h_'+sha[:24]+'.png'
  (SHARED/name).write_bytes(data)
  manifest.setdefault(name,{'sha256':sha,'source_names':[],'models':[]})
  if im.get('name','') not in manifest[name]['source_names']:manifest[name]['source_names'].append(im.get('name',''))
  manifest[name]['models'].append(path.name)
  image_views.add(i);del im['bufferView'];im.pop('mimeType',None);im['uri']='../textures/shared/'+name
 if not image_views:continue
 remap={};out=bytearray();newviews=[]
 for i,v in enumerate(views):
  if i in image_views:continue
  out.extend(b'\0'*((-len(out))%4));nv=dict(v);nv['byteOffset']=len(out)
  off=v.get('byteOffset',0);out.extend(blob[off:off+v['byteLength']]);remap[i]=len(newviews);newviews.append(nv)
 for a in d.get('accessors',[]):
  if 'bufferView' in a:a['bufferView']=remap[a['bufferView']]
  if 'sparse' in a:
   for k in ['indices','values']:a['sparse'][k]['bufferView']=remap[a['sparse'][k]['bufferView']]
 d['bufferViews']=newviews;d['buffers']=[{'byteLength':len(out)}]
 out.extend(b'\0'*((-len(out))%4));j=json.dumps(d,separators=(',',':')).encode();j+=b' '*((-len(j))%4)
 result=struct.pack('<III',0x46546C67,2,28+len(j)+len(out))+struct.pack('<II',len(j),0x4E4F534A)+j+struct.pack('<II',len(out),0x004E4942)+out
 path.write_bytes(result);print(path.name,round(len(b)/1048576,2),'->',round(len(result)/1048576,2),'MiB')
# Godot previously extracted copies with model prefixes. The GLBs now reference shared images directly.
for p in (ROOT/'assets/models').glob('*.png'):
 p.unlink();p.with_name(p.name+'.import').unlink(missing_ok=True)
if manifest:(ROOT/'assets/textures/shared_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Unique original material images:',len(list(SHARED.glob('*.png'))))
