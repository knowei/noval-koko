# -*- coding: utf-8 -*-
"""章节页 SSR 是否含正文；是否有下一章。"""
import io
import re
import requests

S = requests.Session()
S.trust_env = False
UA = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
    'Referer': 'https://www.maiguiread.com/',
}
url = 'https://www.maiguiread.com/novel/6bqYtWlkoay/chapter/6br1gUHU6hj'
r = S.get(url, headers=UA, timeout=40)
print(r.status_code, len(r.content))
io.open('tool/mg_chap.html', 'w', encoding='utf-8').write(r.text)
h = r.text
print('has 牛奶箱:', h.count('牛奶箱'), '| has 下一章:', '下一章' in h, '| has 上一章:', '上一章' in h)
for m in re.finditer('下一章', h):
    print('   ...', h[max(0, m.start() - 200):m.start() + 80].replace('\n', ' ')[-260:])
    break
# 正文容器类名
for cls in ['chapter-content', 'read-content', 'content', 'article', 'reader']:
    found = sorted(set(re.findall(r'class="([^"]*%s[^"]*)"' % cls, h)))
    if found:
        print('  cls', cls, '->', found[:6])
