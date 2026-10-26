import io
import json
import requests

s = requests.Session()
s.trust_env = False
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0 Safari/537.36'
out = []


def totals(r):
    try:
        d = r.json().get('data', {})
        return {k: (v.get('total') if isinstance(v, dict) else None) for k, v in d.items()}
    except Exception:
        return 'not-json:%s' % r.text[:80]


def get(tag, kw, headers=None, **extra):
    p = {'keyword': kw, 'type': 'all', 'page': 1, 'limit': 12}
    p.update(extra)
    h = {'User-Agent': UA, 'Referer': 'https://www.kepub.net/search.html', 'X-Requested-With': 'XMLHttpRequest'}
    h.update(headers or {})
    r = s.get('https://www.kepub.net/search/all', params=p, headers=h, timeout=25)
    out.append('%-42s %s %s' % (tag, r.status_code, json.dumps(totals(r), ensure_ascii=False)))


get('zh-CN accept-lang + 山雨', '山雨', {'Accept-Language': 'zh-CN,zh;q=0.9'})
get('测试作者', '测试作者')
get('Classic', 'Classic')
get('Austen', 'Austen')
get('Jane', 'Jane')
get('Emma', 'Emma')

# 表单 POST
try:
    r = s.post('https://www.kepub.net/search/all',
               data={'keyword': '山雨', 'type': 'all', 'page': 1, 'limit': 12},
               headers={'User-Agent': UA, 'Referer': 'https://www.kepub.net/search.html',
                        'X-Requested-With': 'XMLHttpRequest'},
               timeout=25)
    out.append('POST form -> %s %s %s' % (r.status_code, len(r.content), r.text[:120].replace('\n', ' ')))
except Exception as e:
    out.append('POST form EXC %s' % str(e)[:70])

# suggest
r = s.get('https://www.kepub.net/search/suggest', params={'keyword': '山雨'},
          headers={'User-Agent': UA, 'Referer': 'https://www.kepub.net/search.html',
                   'X-Requested-With': 'XMLHttpRequest'}, timeout=25)
out.append('suggest -> %s %s' % (r.status_code, r.text[:200]))

# 书库分页：看是否包含中文书
import re
for page in [1, 2, 5, 20]:
    r = s.get('https://www.kepub.net/library/book-3-0-0-0-0-0-0-1-%d' % page, headers={'User-Agent': UA}, timeout=25)
    h = r.text
    names = re.findall(r'class="[^"]*book-name[^"]*"[^>]*>([^<]{1,40})', h)
    cjk = [n for n in names if any('\u4e00' <= c <= '\u9fff' for c in n)]
    out.append('library p%-2d %s books=%d 中文=%d sample=%s' % (
        page, r.status_code, len(re.findall(r'href="/book/\d+"', h)), len(cjk),
        json.dumps(cjk[:3], ensure_ascii=False)))

io.open('tool/kp_api7.txt', 'w', encoding='utf-8').write('\n'.join(out))
print('done')
