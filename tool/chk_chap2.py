import re
import sys
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')

u = sys.argv[1]
r = urllib.request.Request(u, headers={'User-Agent': UA,
                                       'Referer': 'https://www.linovelib.com/'})
b = urllib.request.urlopen(r, timeout=25).read().decode('utf-8', 'replace')
print('len', len(b))
for m in re.finditer(r'<div[^>]*(id|class)="[^"]*(Text|txt|content)[^"]*"[^>]*>', b, re.I):
    print('DIV', m.group(0)[:120])
m = re.search(r'<title>(.*?)</title>', b, re.S)
print('TITLE', m.group(1).strip()[:80] if m else '')
for kw in ['未审核', '审核', 'center-note', '请', 'javascript']:
    i = b.find(kw)
    if i >= 0:
        print('KW', kw, '->', b[max(0, i - 80):i + 120].replace('\n', ' ')[:240])
