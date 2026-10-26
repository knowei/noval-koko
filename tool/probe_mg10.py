# -*- coding: utf-8 -*-
"""把 chunk 里所有 api/public 路径挖出来。"""
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
found = set()
for n in names:
    js = S.get(BASE + '/_nuxt/' + n, headers=UA, timeout=30).text
    for m in re.finditer(r'api/(?:public|user|v\d)/[A-Za-z0-9_\-/\$\{\}\.]+', js):
        found.add(m.group(0))
for p in sorted(found):
    print(' ', p)
