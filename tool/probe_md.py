# -*- coding: utf-8 -*-
"""MangaDex 结构探测：搜索 / feed / at-home。"""
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
    log('GET', r.url[:200], '->', r.status_code, len(r.content), 'B')
    return r


# 1) 搜索
r = get(API + '/manga', title='海賊', limit=5,
        **{'includes[]': ['cover_art'],
           'contentRating[]': ['safe', 'suggestive'],
           'order[relevance]': 'desc',
           'originalLanguage[]': ['ja']})
data = r.json()
log('total:', data.get('total'))
for m in data['data'][:3]:
    at = m['attributes']
    log(' id=', m['id'], 'title=', json.dumps(at['title'], ensure_ascii=False)[:90])
    log('   alt=', json.dumps(at.get('altTitles', [])[:2], ensure_ascii=False)[:120])
    log('   status=', at.get('status'), 'year=', at.get('year'),
        'lastChapter=', at.get('lastChapter'), 'lang=', at.get('originalLanguage'))
    log('   desc keys=', list((at.get('description') or {}).keys()))
    for rel in m.get('relationships', []):
        if rel['type'] == 'cover_art':
            log('   cover=', rel.get('attributes').get('fileName'))

mid = data['data'][0]['id']

# 2) feed：看看各语言章节数量
for langs in (['zh', 'zh-hk'], ['en'], ['ja']):
    r = get(API + '/manga/%s/feed' % mid, limit=500,
            **{'translatedLanguage[]': langs,
               'order[chapter]': 'asc',
               'includes[]': ['scanlation_group'],
               'contentRating[]': ['safe', 'suggestive', 'erotica']})
    j = r.json()
    log(' feed langs=%s total=%s got=%d' % (langs, j.get('total'), len(j.get('data', []))))
    if j.get('data'):
        c = j['data'][0]
        ca = c['attributes']
        log('   first chapter: num=%r title=%r pages=%s lang=%s' % (
            ca.get('chapter'), ca.get('title'), ca.get('pages'), ca.get('translatedLanguage')))
        log('   chapter keys=', sorted(ca.keys()))

# 3) at-home
r = get(API + '/manga/%s/feed' % mid, limit=1,
        **{'translatedLanguage[]': ['en'], 'order[chapter]': 'asc'})
cid = r.json()['data'][0]['id']
r = get(API + '/at-home/server/' + cid)
ah = r.json()
log(' baseUrl=', ah.get('baseUrl'), 'hash=', ah['chapter'].get('hash'),
    'data0=', ah['chapter'].get('data', [])[:1], 'saver0=', ah['chapter'].get('dataSaver', [])[:1])

img = '%s/data-saver/%s/%s' % (ah['baseUrl'], ah['chapter']['hash'], ah['chapter']['dataSaver'][0])
r = get(img)
log(' image ctype=', r.headers.get('content-type'), 'bytes=', len(r.content))

with open('tool/md_probe.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))
