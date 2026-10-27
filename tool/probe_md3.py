# -*- coding: utf-8 -*-
"""MangaDex：找一个有图的章节，验证 at-home 节点与 uploads 直连都能下图。"""
import sys

import requests

sys.stdout.reconfigure(encoding='utf-8')

API = 'https://api.mangadex.org'
HEAD = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept': '*/*',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
}
s = requests.Session()
s.trust_env = False
out = []


def log(*a):
    line = ' '.join(str(x) for x in a)
    print(line)
    out.append(line)


MID = 'aa6c76f7-5f5f-46b6-a800-911145f81b9b'  # その着せ替え人形は恋をする
r = s.get(API + '/manga/%s/feed' % MID,
          headers=HEAD,
          params={'translatedLanguage[]': ['en'], 'order[chapter]': 'asc',
                  'limit': 20, 'includeExternalUrl': 0},
          timeout=30)
feed = r.json()['data']
log('feed items:', len(feed))
target = None
for c in feed:
    ca = c['attributes']
    log(' ch=%-6r pages=%-4s ext=%s id=%s' % (
        ca.get('chapter'), ca.get('pages'), ca.get('externalUrl'), c['id']))
    if (ca.get('pages') or 0) > 0 and not ca.get('externalUrl'):
        target = c['id']
        break
log('target:', target)

r = s.get(API + '/at-home/server/' + target, headers=HEAD, timeout=30)
ah = r.json()
base = ah['baseUrl']
h = ah['chapter']['hash']
log('baseUrl:', base)
log('hash:', h, 'pages:', len(ah['chapter'].get('data', [])), 'saver:', len(ah['chapter'].get('dataSaver', [])))
f0 = ah['chapter']['data'][0]
s0 = ah['chapter']['dataSaver'][0]

for name, url in (
    ('node-saver', '%s/data-saver/%s/%s' % (base, h, s0)),
    ('node-data', '%s/data/%s/%s' % (base, h, f0)),
    ('uploads-saver', 'https://uploads.mangadex.org/data-saver/%s/%s' % (h, s0)),
):
    try:
        rr = s.get(url, headers=HEAD, timeout=30)
        log('%-14s %3d %8dB %s %s' % (name, rr.status_code, len(rr.content),
                                       rr.headers.get('content-type'), url[:110]))
    except Exception as e:
        log('%-14s ERR %s %s' % (name, type(e).__name__, str(e)[:80]))

# 顺便看看中文翻译的覆盖率（挑几个人气作）
for kw in ('着せ替え', 'フリーレン', 'チェンソー'):
    r = s.get(API + '/manga', headers=HEAD,
              params={'title': kw, 'limit': 3,
                      'includes[]': ['cover_art'],
                      'originalLanguage[]': ['ja'],
                      'contentRating[]': ['safe', 'suggestive']},
              timeout=30)
    for m in r.json()['data'][:1]:
        for langs in (['zh', 'zh-hk'], ['en']):
            rr = s.get(API + '/manga/%s/feed' % m['id'], headers=HEAD,
                       params={'translatedLanguage[]': langs, 'limit': 1}, timeout=30)
            log('%s %s -> %s' % (kw, langs, rr.json().get('total')))

with open('tool/md_probe3.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))
