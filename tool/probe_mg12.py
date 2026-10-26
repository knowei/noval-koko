# -*- coding: utf-8 -*-
"""1) 找简介容器  2) 测大书 chapter/list 体积。"""
import io
import json
import re
import requests

S = requests.Session()
S.trust_env = False
UA = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Referer': 'https://www.maiguiread.com/',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
}
BASE = 'https://www.maiguiread.com'

h = io.open('tool/mg_novel.html', encoding='utf-8').read()
i = h.find('简介')
print('--- 简介附近 ---')
print(h[max(0, i - 300):i + 600] if i > 0 else 'no 简介')

# 搜索一本大书
r = S.get(BASE + '/search', params={'q': '斗罗大陆'}, headers=UA, timeout=30)
print('\n--- search 斗罗大陆 ---', r.status_code, len(r.content), '| hits:', r.text.count('斗罗大陆'))
rows = re.findall(r'<li class="sr-row".*?</li>', r.text, re.S)
print('rows:', len(rows))
for row in rows[:3]:
    t = re.search(r'<a href="(/novel/[A-Za-z0-9]+)"[^>]*>([^<]+)</a>', row)
    print('  ', t.group(1), '|', t.group(2)) if t else None

# 用 novel/list 找章节多的书
r2 = S.get(BASE + '/api/public/novel/list', params={'page': 1, 'size': 5}, headers={**UA, 'Accept': 'application/json'}, timeout=30)
print('\n--- novel/list ---', r2.status_code, r2.text[:300])
