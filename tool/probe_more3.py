import re
import urllib.parse
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')


def get(u, ref=None):
    h = {'User-Agent': UA}
    if ref:
        h['Referer'] = ref
    r = urllib.request.Request(u, headers=h)
    resp = urllib.request.urlopen(r, timeout=25)
    return resp.geturl(), resp.read().decode('utf-8', 'replace')


fin, b = get('http://s.sfacg.com/?Key=' + urllib.parse.quote('史莱姆') + '&S=1&SS=0')
print('sfacg', fin[:70], len(b), 'kwIn', '史莱姆' in b)
open('tool/ln_probe/sfacg3.html', 'w', encoding='utf-8').write(b)
print('classes', sorted(set(re.findall(r'class="([^"]+)"', b)))[:25])

for f, kw in (('ciyuanji.html', '史莱姆'), ('qbtr.html', '史莱姆'), ('gutenberg.html', 'pride')):
    try:
        body = open('tool/ln_probe/' + f, encoding='utf-8', errors='replace').read()
    except Exception as e:  # noqa: BLE001
        print(f, 'ERR', e)
        continue
    print('=====', f, len(body), 'kwIn', kw in body)
    i = body.find(kw)
    print('  ctx:', body[max(0, i - 400):i + 200].replace('\n', ' ')[:600])
