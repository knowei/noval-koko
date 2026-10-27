# -*- coding: utf-8 -*-
"""把「哔咔漫画（原生源）」加进精选源清单。幂等：同名先删后加。"""
import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

PATH = 'docs/live_sources.json'

PICA = {
    'bookSourceName': '哔咔漫画',
    'bookSourceUrl': 'pica://comic',
    'bookSourceType': 2,
    'bookSourceGroup': '🧩漫画',
    'bookSourceComment': '内置原生源：每个请求自动签名（api-key+timestamp+nonce+method+path 的 HMAC-SHA256），'
                         '需要在本源菜单里用账号登录一次换 token。规则字段留空。',
    'bookUrlPattern': '',
    'customOrder': 0,
    'enabled': True,
    'enabledCookieJar': True,
    'enabledExplore': False,
    'header': '',
    'loginUrl': '',
    'loginCheckJs': '',
    'respondTime': 180000,
    'searchUrl': 'pica://search',
    'ruleSearch': {'bookList': '', 'name': '', 'author': '', 'bookUrl': '',
                   'coverUrl': '', 'intro': '', 'kind': '', 'lastChapter': '',
                   'checkKeyWord': ''},
    'ruleBookInfo': {'init': '', 'name': '', 'author': '', 'intro': '',
                     'coverUrl': '', 'kind': '', 'lastChapter': '',
                     'tocUrl': '', 'wordCount': '', 'updateTime': ''},
    'ruleToc': {'chapterList': '', 'chapterName': '', 'chapterUrl': '',
                'isVip': '', 'isVolume': ''},
    'ruleContent': {'content': '', 'nextContentUrl': '', 'replaceRegex': ''},
}

data = json.load(open(PATH, encoding='utf-8'))
data = [s for s in data if s.get('bookSourceName') != PICA['bookSourceName']]
data.append(PICA)
json.dump(data, open(PATH, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('sources:', len(data))
for s in data:
    print(' -', s['bookSourceName'], s['bookSourceUrl'])
