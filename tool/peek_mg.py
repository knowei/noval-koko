# -*- coding: utf-8 -*-
"""在首页 HTML 里找搜索入口 / API / 书籍链接。"""
import io
import re

h = io.open('tool/mg_home.html', encoding='utf-8').read()

print('--- keyword 上下文 ---')
for m in re.finditer('keyword', h):
    print(repr(h[max(0, m.start() - 120):m.start() + 120]))

print('--- 可能的接口域名 ---')
for m in set(re.findall(r'https?://[a-z0-9.\-]+maigui[a-z0-9.\-]*', h, re.I)):
    print(' ', m)
for m in set(re.findall(r'https?://api[a-z0-9.\-]+', h, re.I)):
    print('  api:', m)

print('--- 站内链接样本 ---')
links = re.findall(r'href="(/[a-z0-9\-]+/[^"]{0,60})"', h)
from collections import Counter
for k, v in Counter([l.split('/')[1] for l in links]).most_common(12):
    print('  /%s/  x%d' % (k, v))
print('  sample:', [l for l in links if '/book' in l][:5])

print('--- script src ---')
for m in re.findall(r'<script[^>]+src="([^"]+)"', h)[:12]:
    print(' ', m)
print('--- 是否 SSR 带了数据 ---')
for key in ['__NUXT__', '__INITIAL_STATE__', 'window.__', 'id="app"', 'data-server-rendered']:
    print(' ', key, key in h)
