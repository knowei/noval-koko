# -*- coding: utf-8 -*-
"""探一下各源对「解忧杂货店」的命中情况。"""
import re
import requests

S = requests.Session()
S.trust_env = False
UA = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
}
KW = '解忧杂货店'

# hetunxs (GBK POST)
try:
    r = S.post('http://m.hetunxs.com/s.php',
               data=b'type=articlename&s=' + KW.encode('gbk') + b'&submit=',
               headers={**UA, 'Content-Type': 'application/x-www-form-urlencoded'},
               timeout=25)
    t = r.content.decode('gbk', 'ignore')
    print('== hetunxs len', len(t))
    for m in re.finditer(r'<a\s+href="([^"]+)"[^>]*>([^<]{2,40})</a>', t):
        if '解忧' in m.group(2):
            print('   ', m.group(1), '|', m.group(2))
except Exception as e:
    print('hetunxs ERR', e)

# sfacg
try:
    r = S.get('http://s.sfacg.com/', params={'Key': KW, 'S': 1, 'SS': 0}, headers=UA, timeout=25)
    print('== sfacg len', len(r.text))
    for m in re.finditer(r'<a[^>]+href="([^"]+)"[^>]*>([^<]{2,40})</a>', r.text):
        if '解忧' in m.group(2):
            print('   ', m.group(1), '|', m.group(2))
except Exception as e:
    print('sfacg ERR', e)

# kepub: 站点到底有没有
try:
    r = S.get('https://www.kepub.net/search/all',
              params={'keyword': KW, 'type': 'all', 'page': 1, 'limit': 20},
              headers={**UA, 'Accept-Language': 'zh-CN,zh;q=0.9', 'Referer': 'https://www.kepub.net/'},
              timeout=25)
    d = r.json().get('data') or {}
    print('== kepub books', (d.get('books') or {}).get('total'),
          'articles', (d.get('articles') or {}).get('total'))
except Exception as e:
    print('kepub ERR', e)
