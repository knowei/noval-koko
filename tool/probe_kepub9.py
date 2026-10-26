import io
import json
import requests

s = requests.Session()
s.trust_env = False
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0 Safari/537.36'
H = {
    'User-Agent': UA,
    'Referer': 'https://www.kepub.net/search.html',
    'X-Requested-With': 'XMLHttpRequest',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'zh-CN,zh;q=0.9',
}
out = []


def search(kw, page=1, limit=12, typ='all'):
    r = s.get('https://www.kepub.net/search/all',
              params={'keyword': kw, 'type': typ, 'page': page, 'limit': limit},
              headers=H, timeout=25)
    d = r.json().get('data', {})
    return r, d


for kw in ['山雨', '鲁迅', '骆驼祥子', '三体', '红楼梦', '朱自清', '散文']:
    r, d = search(kw)
    b = d.get('books', {})
    out.append('%-6s -> %s b=%s a=%s au=%s' % (kw, r.status_code, b.get('total'),
                                                d.get('articles', {}).get('total'),
                                                d.get('authors', {}).get('total')))
    if b.get('list'):
        it = b['list'][0]
        out.append('        first: ' + json.dumps({k: it.get(k) for k in
                    ['bookNo', 'bookName', 'authorName', 'authorNo', 'coverImg', 'bookBrief', 'chapterCount', 'lang', 'isPaid']},
                    ensure_ascii=False))

r, d = search('山雨')
io.open('tool/kp_search_full.json', 'w', encoding='utf-8').write(
    json.dumps(d, ensure_ascii=False, indent=1)[:6000])

# 书页 + 章节页
r = s.get('https://www.kepub.net/book/10044', headers={'User-Agent': UA}, timeout=25)
io.open('tool/kp_book_10044.html', 'w', encoding='utf-8').write(r.text)
out.append('book page %s %dB' % (r.status_code, len(r.content)))

io.open('tool/kp_probe8.txt', 'w', encoding='utf-8').write('\n'.join(out))
print('done')
