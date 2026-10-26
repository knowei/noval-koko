# -*- coding: utf-8 -*-
"""看站点收录的书与章数规模。"""
import json
import re
import requests

S = requests.Session()
S.trust_env = False
UA = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Referer': 'https://www.maiguiread.com/',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
}
BASE = 'https://www.maiguiread.com'

for kw in ['诡秘之主', '三体', '活着', '斗破苍穹', '百年孤独', '白夜行']:
    r = S.get(BASE + '/search', params={'q': kw}, headers=UA, timeout=30)
    m = re.search(r'共(\d+)条', r.text)
    rows = re.findall(r'<li class="sr-row".*?</li>', r.text, re.S)
    first = re.search(r'<a href="(/novel/[A-Za-z0-9]+)"[^>]*>([^<]+)</a>', r.text)
    print(kw, '| 共', m.group(1) if m else '?', '条 | rows', len(rows),
          '| first:', (first.group(1) + ' ' + first.group(2)) if first else '-')
    if first:
        nid = first.group(1).split('/')[-1]
        r2 = S.get(BASE + '/api/public/chapter/list/' + nid, headers={**UA, 'Accept': 'application/json'}, timeout=60)
        try:
            data = r2.json().get('data') or []
            print('     chapters:', len(data), 'payload', round(len(r2.content) / 1024), 'KB')
        except Exception as e:
            print('     list err', e)
