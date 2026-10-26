import gzip, io, ssl, sys, urllib.parse, urllib.request, re

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE


def get(url, ref=None):
    h = {'User-Agent': UA, 'Accept': 'text/html,application/xhtml+xml', 'Accept-Language': 'zh-CN,zh;q=0.9'}
    if ref:
        h['Referer'] = ref
    req = urllib.request.Request(url, headers=h)
    with urllib.request.urlopen(req, timeout=20, context=ctx) as r:
        raw = r.read()
        if r.headers.get('Content-Encoding') == 'gzip':
            raw = gzip.decompress(raw)
        return raw.decode('utf-8', errors='ignore')


def save(name, text):
    io.open('tool/ln_probe/%s.utf8.html' % name, 'w', encoding='utf-8').write(text)
    print('saved', name, len(text))


book = 'https://www.linovel.net/book/102146.html'
t = get(book)
save('book_102146', t)
# 找目录相关容器
for pat in [r'class="[^"]*(catalog|chapter|volume|dir|list)[^"]*"', r'id="[^"]*(catalog|chapter|volume)[^"]*"']:
    print(pat, sorted(set(re.findall(pat, t)))[:20])
print('chapter-ish links:', sorted(set(re.findall(r'href="(/book/102146/\d+\.html)"', t)))[:5])
print('count chapter links:', len(set(re.findall(r'/book/102146/\d+\.html', t))))
