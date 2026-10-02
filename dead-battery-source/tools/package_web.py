"""Split the unchanged Godot pack into uploadable, cache-safe download parts."""
import hashlib
import json
from pathlib import Path

web = Path(__file__).resolve().parents[1] / 'web'
data = (web / 'first-person.pck').read_bytes()
parts = []
for old in web.glob('first-person-*.bin'):
    old.unlink()
for offset in range(0, len(data), 24 * 1024 * 1024):
    block = data[offset:offset + 24 * 1024 * 1024]
    digest = hashlib.sha256(block).hexdigest()
    name = 'first-person-' + digest[:16] + '.bin'
    (web / name).write_bytes(block)
    parts.append({'url': name, 'offset': offset, 'size': len(block), 'sha256': digest})
manifest = {'size': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'parts': parts}
(web / 'first-person-pack.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Browser pack:', len(parts), 'parts /', len(data), 'bytes')
