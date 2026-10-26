# -*- coding: utf-8 -*-
"""试 apiBase 下的公开接口。"""
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

for path, params in [
    ('/api/public/novel/%s' % NID, None),
    ('/api/public/novel/%s/chapters' % NID, None),
    ('/api/public/novel/%s/chapter' % NID, None),
    ('/api/public/chapter/6br1gUHU6hj', None),
    ('/api/public/novel/%s/catalog' % NID, None),
]:
    try:
        r = S.get(BASE + path, params=params, headers=UA, timeout=25)
        print('==', path, r.status_code, r.headers.get('content-type'), len(r.content))
        if r.headers.get('content-type', '').startswith('application/json'):
            d = r.json()
            txt = json.dumps(d, ensure_ascii=False)
            print('   json head:', txt[:400])
            open('tool/mg_api_%s.json' % path.strip('/').replace('/', '_'), 'w', encoding='utf-8').write(txt)
        else:
            print('   body:', r.text[:150])
    except Exception as e:
        print('==', path, 'ERR', type(e).__name__, e)
