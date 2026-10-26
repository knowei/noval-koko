# -*- coding: utf-8 -*-
"""下载所有 Nuxt chunk，抓 flask-api 下的接口路径。"""
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
entry = open('tool/mg_entry.js', encoding='utf-8').read()
names = sorted(set(re.findall(r'[_A-Za-z0-9\-]{6,14}\.js', entry)))
print('chunks:', len(names))

paths = set()
for n in names:
    try:
        js = S.get(BASE + '/_nuxt/' + n, headers=UA, timeout=30).text
    except Exception as e:
        print('skip', n, e)
        continue
    for m in re.finditer(r'''["'`](/[a-z0-9_/\-\{\}\$\.]{2,60})["'`]''', js):
        p = m.group(1)
        low = p.lower()
        if any(k in low for k in ('/api', 'search', 'novel', 'chapter', 'book', 'category', 'rank')):
            paths.add(p)
for p in sorted(paths):
    print('  ', p)
