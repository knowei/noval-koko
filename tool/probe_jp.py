import gzip, io, ssl, re, sys, urllib.parse, urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE


def fetch(url, data=None, ref=None, enc='utf-8'):
    h = {
        'User-Agent': UA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,ja;q=0.8',
        'Referer': ref or url.split('?')[0],
    }
    body = urllib.parse.urlencode(data).encode() if data else None
    if body:
        h['Content-Type'] = 'application/x-www-form-urlencoded'
    req = urllib.request.Request(url, data=body, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=20, context=ctx) as r:
            raw = r.read()
            if r.headers.get('Content-Encoding') == 'gzip':
                raw = gzip.decompress(raw)
            return r.status, raw.decode(enc, errors='ignore'), r.geturl()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(enc, errors='ignore'), url
    except Exception as e:
        return 'ERR', str(e)[:100], url


KEY = '史莱姆'
q = urllib.parse.quote(KEY)
tests = [
    ('esj_tag', 'https://www.esjzone.cc/tags/%s/' % q, None),
    ('esj_search_get', 'https://www.esjzone.cc/search?keyword=%s' % q, None),
    ('esj_search_post', 'https://www.esjzone.cc/search', {'keyword': KEY}),
    ('esj_one_tag', 'https://www.esjzone.one/tags-01/%s/1.html' % q, None),
    ('bilinovel_get', 'https://www.bilinovel.com/search/%s_1.html' % q, None),
    ('bilinovel_get2', 'https://www.bilinovel.com/search/?searchkey=%s' % q, None),
    ('wenku8_ua', 'https://www.wenku8.net/modules/article/search.php?searchtype=articlename&searchkey=%s' % urllib.parse.quote(KEY.encode('gbk')), None),
    ('masiro_home', 'https://masiro.me/admin', None),
    ('lnovel_tw2', 'https://lnovel.tw/books?q[name_cont]=%s' % q, None),
    ('sfacg_api2', 'https://m.sfacg.com/API/HTML5.ashx?op=search&keyword=%s' % q, None),
    ('ciyuanji2', 'https://www.ciyuanji.com/search/%s_0_0_0_0_0_1.html' % q, None),
]

out = {}
for name, url, data in tests:
    code, text, eff = fetch(url, data)
    hits = text.count(KEY)
    links = sorted(set(re.findall(r'href="(/(?:tsukkomi|forum|novel|book|comic|detail|post|article)/[^"#]{2,60})"', text)))
    out[name] = (code, len(text), hits, eff, links[:6])
    print('%-16s %-4s %7d hits=%-3d links=%-3d %s' %
          (name, code, len(text), hits, len(links), eff[:60]))
    io.open('tool/ln_probe/%s.html' % name, 'w', encoding='utf-8').write(text)

print('--- esj_search_post sample ---')
t = out['esj_search_post']
print(t[0], t[1], t[2], t[4])
