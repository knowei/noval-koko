import gzip, io, ssl, re, urllib.request

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


url = 'https://www.linovel.net/book/102146/19871.html'
t = get(url, ref='https://www.linovel.net/book/102146.html')
io.open('tool/ln_probe/chap_19871.utf8.html', 'w', encoding='utf-8').write(t)
print('len', len(t))
print('classes:', ' '.join(sorted(set(re.findall(r'class="([a-zA-Z0-9_\- ]{2,40})"', t)))[:60]))
for tag in ('article', 'h1', 'content', 'text'):
    m = [x.start() for x in re.finditer(tag, t)]
    print(tag, len(m))
i = t.find('波澜的开端')
print('--- around title ---')
print(t[max(0, i - 800):i + 200])
