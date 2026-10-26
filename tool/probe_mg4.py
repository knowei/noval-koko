# -*- coding: utf-8 -*-
"""下载 Nuxt bundle，找搜索相关接口路径。"""
import re
import requests

S = requests.Session()
S.trust_env = False
UA = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
}
BASE = 'https://www.maiguiread.com'

entry = S.get(BASE + '/_nuxt/B79JIYQH.js', headers=UA, timeout=30).text
open('tool/mg_entry.js', 'w', encoding='utf-8').write(entry)
chunks = sorted(set(re.findall(r'"(\./[A-Za-z0-9_\-]+\.js)"', entry) +
                    re.findall(r'"(/_nuxt/[A-Za-z0-9_\-]+\.js)"', entry)))
print('entry len', len(entry), 'chunks', len(chunks))

hits = []
for c in chunks[:400]:
    url = BASE + ('/' + c.lstrip('./') if c.startswith('./') else c)
    try:
        js = S.get(url, headers=UA, timeout=30).text
    except Exception:
        continue
    if 'search' in js.lower() and ('flask' in js or 'api' in js):
        for m in re.finditer(r'''["'`](/?[a-z0-9_/\-]*(?:search|Search)[a-z0-9_/\-]*)["'`]''', js):
            hits.append((c, m.group(1)))
        if '/flask-api' in js or 'flask' in js:
            for m in re.finditer(r'''["'`](/[a-z0-9_/\-]{2,40})["'`]''', js):
                p = m.group(1)
                if any(k in p.lower() for k in ('search', 'novel', 'book', 'chapter', 'read')):
                    hits.append((c, p))
print('hits', len(hits))
seen = set()
for c, p in hits:
    if p in seen:
        continue
    seen.add(p)
    print('  ', p, '   <-', c)
