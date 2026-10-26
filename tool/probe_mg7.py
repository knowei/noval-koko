# -*- coding: utf-8 -*-
"""探 maiguiread 详情页 / 章节页结构。"""
import io
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
NID = '6bqYtWlkoay'

r = S.get(BASE + '/novel/' + NID, headers=UA, timeout=30)
print('detail', r.status_code, len(r.content))
io.open('tool/mg_novel.html', 'w', encoding='utf-8').write(r.text)
h = r.text

print('--- og/meta ---')
for m in re.finditer(r'<meta[^>]+(?:property|name)="([^"]+)"[^>]+content="([^"]{0,120})"', h):
    if 'og:' in m.group(1) or m.group(1) in ('description', 'keywords'):
        print('  ', m.group(1), '=', m.group(2)[:100])

print('--- 章节链接 ---')
chaps = re.findall(r'href="(/novel/[A-Za-z0-9]+/chapter/[A-Za-z0-9]+)"[^>]*>(.{0,50}?)<', h)
print('  count', len(chaps))
for c in chaps[:6]:
    print('   ', c[0], '|', re.sub(r'<[^>]+>', '', c[1]).strip())

print('--- 关键 class ---')
for cls in ['novel-', 'chapter', 'book-info', 'detail', 'intro', 'catalog', 'toc']:
    found = sorted(set(re.findall(r'class="([^"]*%s[^"]*)"' % cls, h)))
    if found:
        print('  ', cls, '->', found[:8])
