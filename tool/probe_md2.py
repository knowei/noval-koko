# -*- coding: utf-8 -*-
"""MangaDex：拿热门日漫，验证 feed / at-home / 图片下载。"""
import json
import sys

import requests

sys.stdout.reconfigure(encoding='utf-8')

API = 'https://api.mangadex.org'
HEAD = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept': 'application/json',
    'Accept-Language': 'zh-CN,zh;q=0.9,ja;q=0.8,en;q=0.7',
}

s = requests.Session()
s.trust_env = False
out = []


def log(*a):
    line = ' '.join(str(x) for x in a)
    print(line)
    out.append(line)


def get(url, **params):
    r = s.get(url, headers=HEAD, params=params, timeout=30)
    log('GET', r.url[:160], '->', r.status_code, len(r.content), 'B')
    return r


# 热门日漫
r = get(API + '/manga', limit=6,
        **{'includes[]': ['cover_art'],
           'contentRating[]': ['safe', 'suggestive'],
           'originalLanguage[]': ['ja'],
           'order[followedCount]': 'desc'})
data = r.json()
log('popular total:', data.get('total'))
picked = None
for m in data['data']:
    at = m['attributes']
    ja = [t.get('ja') for t in at.get('altTitles', []) if t.get('ja')]
    log(' %-38s %-40s ja=%s' % (m['id'], (at['title'].get('en') or '')[:38], ja[:1]))
    if picked is None:
        picked = m['id']

mid = picked
log('picked:', mid)

for langs in (['zh', 'zh-hk'], ['en'], ['ja']):
    r = get(API + '/manga/%s/feed' % mid, limit=3,
            **{'translatedLanguage[]': langs, 'order[chapter]': 'asc',
               'includes[]': ['scanlation_group']})
    j = r.json()
    log('  feed %s total=%s got=%d' % (langs, j.get('total'), len(j.get('data', []))))
    for c in j.get('data', [])[:2]:
        ca = c['attributes']
        log('    ch=%r title=%r pages=%s lang=%s' % (
            ca.get('chapter'), ca.get('title'), ca.get('pages'), ca.get('translatedLanguage')))

r = get(API + '/manga/%s/feed' % mid, limit=1,
        **{'translatedLanguage[]': ['en'], 'order[chapter]': 'asc'})
cid = r.json()['data'][0]['id']
r = get(API + '/at-home/server/' + cid)
ah = r.json()
log('  baseUrl=', ah.get('baseUrl'))
log('  hash=', ah['chapter'].get('hash'), 'pages=', len(ah['chapter'].get('data', [])))
log('  data0=', ah['chapter'].get('data', [])[:1], 'saver0=', ah['chapter'].get('dataSaver', [])[:1])
img = '%s/data-saver/%s/%s' % (ah['baseUrl'], ah['chapter']['hash'], ah['chapter']['dataSaver'][0])
r = get(img)
log('  image', r.headers.get('content-type'), len(r.content), 'B')

with open('tool/md_probe2.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))
