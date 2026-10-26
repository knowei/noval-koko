"""验证哔哩轻小说封面图是否需要 Referer；顺便看 book 8 目录里有没有卷标题。"""

import re
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')
IMG = 'https://www.linovelib.com/files/article/image/0/8/8s.jpg?182323'


def fetch(url, headers):
    req = urllib.request.Request(url, headers=headers)
    try:
        r = urllib.request.urlopen(req, timeout=30)
        return r.status, len(r.read()), r.headers.get('Content-Type')
    except Exception as e:  # noqa: BLE001
        return 'ERR', str(e), ''


print('no referer :', fetch(IMG, {'User-Agent': UA}))
print('with ref   :', fetch(IMG, {'User-Agent': UA,
                                 'Referer': 'https://www.linovelib.com/'}))
print('no UA      :', fetch(IMG, {}))

req = urllib.request.Request('https://www.linovelib.com/novel/8/catalog',
                             headers={'User-Agent': UA,
                                      'Referer': 'https://www.linovelib.com/'})
c = urllib.request.urlopen(req, timeout=40).read().decode('utf-8', 'replace')
print('catalog len', len(c))
print('h2 count', c.count('<h2'))
for m in list(re.finditer(r'<h2[^>]*>(.{0,200}?)</h2>', c, re.S))[:3]:
    print('H2>', m.group(1).replace('\n', ' '))
print('volume-info count', c.count('volume-info'))
print('vol_ links', len(re.findall(r'/vol_\d+\.html', c)))
