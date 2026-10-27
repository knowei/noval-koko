# -*- coding: utf-8 -*-
"""日漫站点批量探活：只看「能不能到 + 是不是真内容」，不做解析。"""
import json
import sys
import time

import requests

sys.stdout.reconfigure(encoding='utf-8')

TARGETS = [
    ('mangadex-api', 'https://api.mangadex.org/manga?limit=1&title=%E6%9D%B1%E4%BA%AC'),
    ('mangadex-site', 'https://mangadex.org/'),
    ('mangadex-uploads', 'https://uploads.mangadex.org/'),
    ('comick-api', 'https://api.comick.fun/v1.0/search?q=one&limit=1'),
    ('comick-site', 'https://comick.io/'),
    ('mangafire', 'https://mangafire.to/'),
    ('klmanga', 'https://klmanga.org/'),
    ('rawkuma', 'https://rawkuma.com/'),
    ('mangapark', 'https://mangapark.net/'),
    ('mangakakalot', 'https://mangakakalot.com/'),
    ('bato', 'https://bato.to/'),
    ('ninemanga', 'https://ninemanga.com/'),
    ('mangacopy-api', 'https://api.mangacopy.com/api/v3/search/comic?q=one&limit=1'),
    ('copymanga-web', 'https://www.mangacopy.com/'),
    ('jm', 'https://18comic.vip/'),
    ('baozimh-mirror', 'https://bzmh.org/s?q=%E6%B5%B7%E8%B4%BC'),
]

HEAD = {
    'User-Agent': ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                   '(KHTML, like Gecko) Chrome/124.0 Safari/537.36'),
    'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,ja;q=0.8,en;q=0.7',
}

s = requests.Session()
s.trust_env = False

lines = []
for name, url in TARGETS:
    t0 = time.time()
    try:
        r = s.get(url, headers=HEAD, timeout=20, allow_redirects=True)
        ms = int((time.time() - t0) * 1000)
        body = r.content
        text = body.decode('utf-8', 'replace')
        note = ''
        low = text.lower()
        if 'just a moment' in low or 'cf-mitigated' in str(r.headers).lower() or 'challenge' in low[:4000]:
            note = ' [CF验证页]'
        if 'cloudflare' in str(r.headers.get('server', '')).lower():
            note += ' [server=cloudflare]'
        line = '%-16s %3d %8dB %5dms %s%s' % (name, r.status_code, len(body), ms, r.url, note)
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        line = '%-16s ERR %5dms %s: %s' % (name, ms, type(e).__name__, str(e)[:90])
    print(line)
    lines.append(line)

with open('tool/manga_probe.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
