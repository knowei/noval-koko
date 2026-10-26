import io
import re
import json
import requests

s = requests.Session()
s.trust_env = False
H = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0 Safari/537.36'}

out = []


def say(x):
    out.append(x)


r = s.get('https://www.kepub.net/library', headers=H, timeout=30)
h = r.text
io.open('tool/kp_library.html', 'w', encoding='utf-8').write(h)
say('library %s %dB' % (r.status_code, len(h)))

say('scripts: ' + json.dumps(re.findall(r'<script[^>]*src="([^"]+)"', h), ensure_ascii=False))
say('forms: ' + json.dumps(re.findall(r'<form[^>]*>', h)[:6], ensure_ascii=False))
say('paths: ' + json.dumps(sorted(set(re.findall(r'/(?:api|search|library|book|filter)[a-zA-Z0-9_/\-]*', h)))[:25], ensure_ascii=False))
say('links: %d' % len(re.findall(r'href="/book/\d+"', h)))

# 搜 library 页里的 js
for src in re.findall(r'<script[^>]*src="([^"]+)"', h):
    if 'common' in src or 'jquery' in src:
        continue
    try:
        jr = s.get('https://www.kepub.net' + ('' if src.startswith('http') else src), headers=H, timeout=30)
        js = jr.text
        name = src.split('/')[-1].split('?')[0]
        io.open('tool/kp_js_' + name, 'w', encoding='utf-8').write(js)
        hits = re.findall(r"url:\s*'([^']+)'|fetch\(\s*'([^']+)'|\\\$\.get\(\s*'([^']+)'", js)
        flat = [' '.join(t).strip() for t in hits][:15]
        say('js %s %dB urls=%s' % (src, len(js), json.dumps(flat, ensure_ascii=False)))
    except Exception as e:
        say('js %s EXC %s' % (src, str(e)[:60]))

io.open('tool/kp_lib_probe.txt', 'w', encoding='utf-8').write('\n'.join(out))
print('done', len(out))
