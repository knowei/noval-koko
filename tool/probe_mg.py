# -*- coding: utf-8 -*-
"""maiguiread.com 结构侦察：首页 / 搜索 / 详情 / 目录 / 正文。"""
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


def get(url, **kw):
    try:
        r = S.get(url, headers=UA, timeout=30, allow_redirects=True, **kw)
        print('==', url, '->', r.status_code, len(r.content), r.headers.get('content-type'),
              'final:', r.url if r.url != url else '')
        return r
    except Exception as e:
        print('==', url, 'ERR', type(e).__name__, e)
        return None


r = get(BASE + '/')
if r is not None:
    html = r.text
    open('tool/mg_home.html', 'w', encoding='utf-8').write(html)
    print('   title:', re.findall(r'<title>(.*?)</title>', html, re.S)[:1])
    # 搜索表单
    for m in re.finditer(r'<form[^>]*>', html):
        print('   form:', m.group(0)[:200])
    # js 里的搜索接口线索
    for kw in ['search', 's.php', 'api/', 'keyword']:
        hits = [m.start() for m in re.finditer(kw, html)]
        print('   kw', kw, 'hits', len(hits))
    for m in re.finditer(r'(?:action|href)="([^"]*(?:search|so|sou)[^"]*)"', html):
        print('   search-link:', m.group(1))
