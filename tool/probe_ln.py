import io, ssl, urllib.parse, urllib.request, gzip, zlib, os, json, sys

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
KEY = '史莱姆'
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

os.makedirs('tool/ln_probe', exist_ok=True)


def dec(raw, enc=None):
    for e in ([enc] if enc else []) + ['utf-8', 'gbk', 'gb18030', 'big5']:
        if not e:
            continue
        try:
            return raw.decode(e, errors='strict')
        except Exception:
            continue
    return raw.decode('utf-8', errors='ignore')


def fetch(name, url, data=None, enc=None, headers=None):
    h = {'User-Agent': UA, 'Accept': '*/*', 'Accept-Language': 'zh-CN,zh;q=0.9',
         'Referer': url.split('?')[0]}
    if headers:
        h.update(headers)
    body = None
    if data is not None:
        body = urllib.parse.urlencode(data, encoding=enc or 'utf-8').encode()
        h['Content-Type'] = 'application/x-www-form-urlencoded'
    req = urllib.request.Request(url, data=body, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=15, context=ctx) as r:
            raw = r.read()
            if r.headers.get('Content-Encoding') == 'gzip':
                raw = gzip.decompress(raw)
            text = dec(raw, enc)
            hits = text.count(KEY) + text.count(urllib.parse.quote(KEY))
            code = r.status
            eff = r.geturl()
    except urllib.error.HTTPError as e:
        raw = e.read()
        text = dec(raw, enc)
        hits = text.count(KEY)
        code = e.code
        eff = url
    except Exception as e:
        return dict(name=name, code='ERR', size=0, hits=0, url=url, note=str(e)[:80])
    p = 'tool/ln_probe/%s.html' % name.replace('/', '_').replace(':', '_')
    io.open(p, 'wb').write(raw)
    return dict(name=name, code=code, size=len(raw), hits=hits, url=eff,
                note=text[:60].replace('\n', ' '))


K = urllib.parse.quote(KEY)
tests = [
    ('xbq03', 'https://www.xbq03.com/search.php', {'submit': '搜索', 'searchkey': KEY}, None),
    ('esjzone_one', 'https://www.esjzone.one/tags-01/%s/1.html' % K, None, None),
    ('esjzone_net', 'https://www.esjzone.net/tags/%s/' % K, None, None),
    ('esjzone_me', 'https://www.esjzone.me/tags/%s/' % K, None, None),
    ('esjzone_cc', 'https://www.esjzone.cc/tags/%s/' % K, None, None),
    ('sfacg_s', 'http://s.sfacg.com/?Key=%s&S=1&SS=0' % K, None, 'gbk'),
    ('sfacg_api', 'https://m.sfacg.com/API/HTML5.ashx?op=search&keyword=%s' % K, None, None),
    ('linovelib_post', 'https://www.linovelib.com/search.html', {'searchkey': KEY, 'searchtype': 'all'}, None),
    ('linovelib_w', 'https://w.linovelib.com/search.html', {'searchkey': KEY, 'searchtype': 'all'}, None),
    ('bilinovel_post', 'https://www.bilinovel.com/search.html', {'searchkey': KEY}, None),
    ('wenku8_cc', 'https://www.wenku8.cc/modules/article/search.php?searchtype=articlename&searchkey=%s&page=1' % urllib.parse.quote(KEY.encode('gbk')), None, 'gbk'),
    ('wenku8_net', 'https://www.wenku8.net/modules/article/search.php?searchtype=articlename&searchkey=%s&page=1' % urllib.parse.quote(KEY.encode('gbk')), None, 'gbk'),
    ('lightnovel_us', 'https://www.lightnovel.us/search?keywords=%s' % K, None, None),
    ('shencou', 'http://m.shencou.com/modules/article/search.php', {'s': KEY, 'type': 'articlename'}, 'gbk'),
    ('yodu', 'https://www.yodu.org/sa/all-%s-1.html' % K, None, None),
    ('ciyuanji', 'https://www.ciyuanji.com/search/%s_0_0_0_0_0_1.html' % K, None, None),
    ('lnovel_tw', 'https://lnovel.tw/books?page=1&q%%5Bname_cont%%5D=%s' % K, None, None),
    ('acgzc', 'http://www.acgzc.com/index.php/portal/booklist/?list=true&keywords=%s&per_page=1' % K, None, None),
    ('jyacg', 'https://jyapi.jyacg.com/web/search?name=%s&page=1&type=1' % K, None, None),
    ('acggg', 'http://novel.acg.gg/modules/article/search.php', {'searchkey': KEY}, 'gbk'),
    ('danwenku', 'https://danwenku.com/e/search/index.php', {'keyboard': KEY, 'show': 'title,newstext'}, 'gbk'),
    ('tmxs', 'http://www.tmxs.net/plus/search.php', {'kwtype': '0', 'keyword': KEY}, 'gb2312'),
    ('masiro', 'https://masiro.me/admin/loadMoreNovels?page=1&keyword=%s' % K, None, None),
    ('bestlightnovel', 'https://bestlightnovel.com/search_novels/%s?page=1' % K, None, None),
    ('linovel_net', 'https://www.linovel.net/search/?kw=%s&page=1' % K, None, None),
    ('2cyxsw', 'http://www.2cyxsw.com/modules/article/search.php?searchkey=%s' % urllib.parse.quote(KEY.encode('gbk')), None, 'gbk'),
]

rows = []
for t in tests:
    r = fetch(*t)
    rows.append(r)
    print('%-14s %-4s %8d hits=%-3d %s' % (r['name'], r['code'], r['size'], r['hits'], r['url'][:70]))

io.open('tool/ln_probe.txt', 'w', encoding='utf-8').write(
    '\n'.join('%-14s %-4s %8d hits=%-3d %s' % (r['name'], r['code'], r['size'], r['hits'], r['url']) for r in rows))
