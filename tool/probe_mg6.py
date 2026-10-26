# -*- coding: utf-8 -*-
"""探 /search 页面。"""
import re
import requests

S = requests.Session()
S.trust_env = False
UA = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Referer': 'https://www.maiguiread.com/',
}
BASE = 'https://www.maiguiread.com'
KW = '解忧杂货店'

for qs in [{'keyword': KW}, {'kw': KW}, {'q': KW}, {'key': KW}]:
    r = S.get(BASE + '/search', params=qs, headers=UA, timeout=30)
    html = r.text
    print(qs, '->', r.status_code, len(html), '| kw in html:', KW in html,
          '| 解忧:', html.count('解忧'), '| /novel/:', len(set(re.findall(r'/novel/[A-Za-z0-9]+', html))))
    if KW in html or '解忧' in html:
        open('tool/mg_search.html', 'w', encoding='utf-8').write(html)
        titles = re.findall(r'<h[23][^>]*>(.{0,60}?)</h[23]>', html, re.S)
        print('   h2/h3:', [re.sub(r'<[^>]+>', '', t).strip() for t in titles][:8])
        print('   novel links:', sorted(set(re.findall(r'/novel/[A-Za-z0-9]+', html)))[:8])
        break
