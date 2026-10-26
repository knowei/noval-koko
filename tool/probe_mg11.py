# -*- coding: utf-8 -*-
"""取章节列表。"""
import json
import requests

S = requests.Session()
S.trust_env = False
UA = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Referer': 'https://www.maiguiread.com/',
    'Accept': 'application/json',
}
BASE = 'https://www.maiguiread.com'
NID = '6bqYtWlkoay'

r = S.get(BASE + '/api/public/chapter/list/' + NID, headers=UA, timeout=25)
print(r.status_code, r.headers.get('content-type'), len(r.content))
d = r.json()
print('code', d.get('code'), 'data type', type(d.get('data')).__name__)
data = d.get('data')
if isinstance(data, dict):
    print('keys:', list(data.keys()))
    lst = data.get('list') or data.get('chapters') or []
else:
    lst = data or []
print('items:', len(lst))
for it in lst[:5]:
    print('  ', json.dumps(it, ensure_ascii=False)[:160])
open('tool/mg_chapters.json', 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=1))
