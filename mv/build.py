"""Build the self-contained MV page: subset the font, inline audio + audio features."""
import base64, io, json, pathlib, re
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).parent
src = (ROOT / 'src/mv.html').read_text(encoding='utf-8')

chars = set(re.findall(r'[^\x00-\x7f]', src)) | set(map(chr, range(0x20, 0x7f)))
font = TTFont(ROOT / 'assets/ZCOOLKuaiLe-Regular.ttf')
opts = subset.Options(); opts.flavor = 'woff2'
sub = subset.Subsetter(opts); sub.populate(text=''.join(chars)); sub.subset(font)
buf = io.BytesIO(); font.flavor = 'woff2'; font.save(buf)

feat = json.loads((ROOT / 'assets/feat.json').read_text())
out = (src.replace('/*FONT*/', base64.b64encode(buf.getvalue()).decode())
          .replace('/*FEAT*/', json.dumps(feat, separators=(',', ':')))
          .replace('/*AUDIO*/', base64.b64encode((ROOT / 'assets/song.m4a').read_bytes()).decode()))
(ROOT / 'index.html').write_text(out, encoding='utf-8')
print('index.html', len(out) // 1024, 'KB')
