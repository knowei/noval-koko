# -*- coding: utf-8 -*-
"""chapter/list 是否支持分页/瘦身。"""
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

for params in [None, {'page': 1, 'size': 2}, {'size': 2}, {'page': 2, 'size': 2},
               {'fields': 'cid,title'}, {'simple': 1}, {'withContent': 0}]:
    url = BASE + '/api/public/chapter/list/' + NID
    r = S.get(url, params=params, headers=UA, timeout=30)
    try:
        d = r.json()
        data = d.get('data')
        n = len(data) if isinstance(data, list) else '?'
        has = ''
        if isinstance(data, list) and data:
            has = 'content?' + str('content' in data[0]) + ' ' + str(len(data[0].get('content') or ''))
        print(params, '->', r.status_code, len(r.content), 'items', n, has)
    except Exception as e:
        print(params, '->', r.status_code, 'parse err', e)
