"""通用「包子系」漫画站侦察：搜索 → 详情 → 目录 → 章节（判断是否同构于 baozimh.org）。"""
import json
import re
import sys

import requests

requests.packages.urllib3.disable_warnings()
UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')
S = requests.Session()
S.trust_env = False
S.headers.update({'User-Agent': UA, 'Accept-Language': 'zh-CN,zh;q=0.9',
                  'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8'})
S.verify = False

BASE = sys.argv[1].rstrip('/')
KW = sys.argv[2] if len(sys.argv) > 2 else '斗罗大陆'


def g(url):
    return S.get(url, timeout=20)


def txt(html):
    return re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', '', html)).strip()


print(f'##### {BASE} #####')
print('1) 搜索', KW)
r = g(f'{BASE}/s?q={requests.utils.quote(KW)}')
print('   HTTP', r.status_code, len(r.content))
open('tool/mh_search.html', 'w', encoding='utf-8').write(r.text)
manga = re.findall(r'href="(/manga/[^"#?]+)"', r.text)
print('   /manga/ 链接:', len(manga), manga[:5])
titles = re.findall(r'<h3[^>]*class="[^"]*cardtitle[^"]*"[^>]*>(.*?)</h3>', r.text, re.S)
print('   卡片标题:', [txt(t)[:24] for t in titles[:6]])
if not manga:
    sys.exit('无结果，停止')

slug = manga[0].strip('/').split('/')[-1]
print('\n2) 详情', slug)
rb = g(f'{BASE}/manga/{slug}')
print('   HTTP', rb.status_code, len(rb.content))
open('tool/mh_book.html', 'w', encoding='utf-8').write(rb.text)
t = re.search(r'<title[^>]*>(.*?)</title>', rb.text, re.S)
print('   title:', txt(t.group(1))[:60] if t else '')
for pat, label in [(r'<h1[^>]*>(.*?)</h1>', 'h1'),
                   (r'property="og:description"\s+content="([^"]*)"', 'og:desc'),
                   (r'id="allchapters"[^>]*data-mid="(\d+)"', 'data-mid'),
                   (r'href="(/chapterlist/[^"]+)"', 'chapterlist'),
                   (r'<img[^>]+class="[^"]*object-cover[^"]*"[^>]*src="([^"]+)"', 'cover'),
                   (r'<img[^>]+src="([^"]+)"[^>]*class="[^"]*object-cover', 'cover2')]:
    m = re.findall(pat, rb.text, re.S)
    print(f'   {label}: {len(m)} -> {[txt(str(x))[:60] for x in m[:3]]}')

cl = re.findall(r'href="(/chapterlist/[^"]+)"', rb.text)
toc_url = f'{BASE}{cl[0]}' if cl else f'{BASE}/chapterlist/{slug}'
print('\n3) 目录', toc_url)
rt = g(toc_url)
print('   HTTP', rt.status_code, len(rt.content))
open('tool/mh_toc.html', 'w', encoding='utf-8').write(rt.text)
print('   /api/ 出现:', sorted(set(re.findall(r'https?://[a-z0-9.\-]*apikk\.top[^"\'\\ ]*', rt.text)))[:3])
api = re.findall(r'(https?://[^"\'\\ ]*apikk\.top[^"\'\\ ]*/api/[^"\'\\ ]*)', rt.text)
print('   api 线索:', api[:3])
mid = re.findall(r'data-mid="(\d+)"', rt.text)
print('   data-mid:', mid[:3])

if mid:
    u = f'https://v2.apikk.top/api/manga/get?mid={mid[0]}&mode=all'
    ra = g(u)
    print('\n4) 目录 API', u, '->', ra.status_code, len(ra.content))
    try:
        j = ra.json()
        ch = j.get('data', {}).get('chapters', [])
        print('   章节数:', len(ch), '首章:', ch[0]['attributes'].get('title') if ch else None)
        print('   首章 slug:', ch[0]['attributes'].get('slug') if ch else None)
        open('tool/mh_toc.json', 'w', encoding='utf-8').write(json.dumps(j, ensure_ascii=False)[:200000])
    except Exception as e:
        print('   JSON 失败', e, ra.text[:200])
