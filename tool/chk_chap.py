import re
import sys
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')


def fetch(u, referer=None):
    h = {'User-Agent': UA}
    if referer:
        h['Referer'] = referer
    r = urllib.request.Request(u, headers=h)
    return urllib.request.urlopen(r, timeout=25).read().decode('utf-8', 'replace')


for u in sys.argv[1:]:
    for ref in (None, 'https://www.linovelib.com/'):
        try:
            b = fetch(u, ref)
            m = re.search(r'id="TextContent"(.*?)</div>', b, re.S)
            t = re.sub(r'<[^>]+>', '', m.group(1)) if m else 'NO-DIV'
            t = t.strip().replace('\n', ' ')
            print(u, 'ref' if ref else 'noref', len(b), '|', len(t), '|', t[:70])
        except Exception as e:  # noqa: BLE001
            print(u, 'ref' if ref else 'noref', 'ERR', e)
