# -*- coding: utf-8 -*-
"""探 maiguiread 的搜索：/category?keyword=、可能的 /api 接口。"""
import re
import requests

S = requests.Session()
S.trust_env = False
UA = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
}
BASE = 'https://www.maiguiread.com'
KW = '解忧杂货店'

r = S.get(BASE + '/category', params={'keyword': KW}, headers=UA, timeout=30)
print('status', r.status_code, len(r.content))
html = r.text
open('tool/mg_cat.html', 'w', encoding='utf-8').write(html)
print('has kw:', KW in html, '| 解忧 hits:', html.count('解忧'))
# 找书籍链接
links = sorted(set(re.findall(r'href="(/[a-z0-9]+/[^"?#]{2,60})"', html)))
print('links sample:', links[:15])
# 找接口
for pat in [r'https?://[a-z0-9.\-]*maigui[a-z0-9.\-]*(/[a-z0-9/_\-]*)?',
            r'"/api/[a-z0-9/_\-]+"']:
    print(pat, '->', sorted(set(re.findall(pat, html)))[:15])
