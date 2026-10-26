import io
import json
import requests

s = requests.Session()
s.trust_env = False
H = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0 Safari/537.36',
    'Referer': 'https://www.kepub.net/search.html',
    'X-Requested-With': 'XMLHttpRequest',
    'Accept': 'application/json, text/plain, */*',
}
KW = '山雨'
out = []


def probe(path, params):
    try:
        r = s.get('https://www.kepub.net' + path, params=params, headers=H, timeout=25)
        ct = r.headers.get('content-type') or ''
        extra = ''
        if 'json' in ct:
            try:
                j = r.json()
                d = j.get('data') if isinstance(j, dict) else None
                if isinstance(d, dict):
                    extra = 'totals=' + json.dumps(
                        {k: (v.get('total') if isinstance(v, dict) else None) for k, v in d.items()},
                        ensure_ascii=False)
                else:
                    extra = 'json-len=%d' % len(r.content)
            except Exception:
                extra = 'json-parse-fail'
        else:
            extra = 'html hits(kw)=%d hits(/book/)=%d' % (r.text.count(KW), r.text.count('/book/'))
        out.append('%-34s %s %6dB %s' % (path, r.status_code, len(r.content), extra))
    except Exception as e:
        out.append('%-34s EXC %s' % (path, str(e)[:70]))


base = {'keyword': KW, 'type': 'all', 'page': 1, 'limit': 12}
for p in ['/search/all', '/search/suggest', '/search/book', '/search/books', '/search/list',
          '/search/booklist', '/book/search', '/book/list', '/book/query', '/api/search',
          '/api/book/search', '/library/search', '/library/list']:
    probe(p, base)

probe('/search/all', {'keyword': KW, 'type': 'all', 'page': 1, 'limit': 12, 'lang': 'zh'})
probe('/search/all', {'keyword': KW, 'type': 'book', 'page': 1, 'limit': 12, 'lang': 'zh'})
probe('/library/book-3-0-0-0-0-0-0-1-1', {})
probe('/library/book-3-0-0-0-0-0-0-1-1', {'keyword': KW})

io.open('tool/kp_api6.txt', 'w', encoding='utf-8').write('\n'.join(out))
print('done')
