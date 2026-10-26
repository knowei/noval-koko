# -*- coding: utf-8 -*-
"""试 flask-api 的搜索端点。"""
import json
import requests

S = requests.Session()
S.trust_env = False
UA = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Referer': 'https://www.maiguiread.com/',
}
BASE = 'https://www.maiguiread.com/flask-api'
KW = '解忧杂货店'

cands = [
    ('GET', '/search', {'keyword': KW}),
    ('GET', '/search', {'kw': KW}),
    ('GET', '/search', {'q': KW}),
    ('GET', '/v1/search', {'keyword': KW}),
    ('GET', '/novel/search', {'keyword': KW}),
    ('GET', '/books', {'keyword': KW}),
    ('GET', '/novel/list', {'keyword': KW}),
    ('GET', '/search/book', {'keyword': KW}),
    ('POST', '/search', {'keyword': KW}),
    ('GET', '/health', None),
]
for method, path, params in cands:
    url = BASE + path
    try:
        if method == 'GET':
            r = S.get(url, params=params, headers=UA, timeout=20)
        else:
            r = S.post(url, json=params, headers=UA, timeout=20)
        body = r.text[:180].replace('\n', ' ')
        print(method, path, params, '->', r.status_code, r.headers.get('content-type'), '|', body)
    except Exception as e:
        print(method, path, 'ERR', type(e).__name__, e)
