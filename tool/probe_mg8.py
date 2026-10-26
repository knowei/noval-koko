# -*- coding: utf-8 -*-
"""在详情页的 Nuxt chunk 里找章节列表接口。"""
import io
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
h = io.open('tool/mg_novel.html', encoding='utf-8').read()
names = sorted(set(re.findall(r'/_nuxt/([_A-Za-z0-9\-]{6,14}\.js)', h)))
print('chunks on page:', len(names), names[:8])

for n in names:
    js = S.get(BASE + '/_nuxt/' + n, headers=UA, timeout=30).text
    if 'chapter' in js.lower() or 'flask' in js.lower():
        # 找 API 拼接
        for m in re.finditer(r'''["'`]([^"'`]{0,40}(?:flask-api|api)[^"'`]{0,60})["'`]''', js):
            print('  API?', n, '->', m.group(1))
        for m in re.finditer(r'''\.get\(\s*["'`]([^"'`]{2,70})["'`]''', js):
            print('  GET?', n, '->', m.group(1))
        for m in re.finditer(r'''fetch\(\s*["'`]([^"'`]{2,70})["'`]''', js):
            print('  FETCH?', n, '->', m.group(1))
