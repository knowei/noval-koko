"""探一遍哔哩轻小说《欢迎来到实力至上主义的教室》：封面 markup + 目录前几章。"""

import re
import urllib.parse
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')


def post_search(key):
    data = urllib.parse.urlencode({'key': key}).encode()
    req = urllib.request.Request(
        'https://www.linovelib.com/S6/',
        data=data,
        headers={'User-Agent': UA,
                 'Referer': 'https://www.linovelib.com/',
                 'Content-Type': 'application/x-www-form-urlencoded'})
    return urllib.request.urlopen(req, timeout=40).read().decode('utf-8', 'replace')


def get(url):
    req = urllib.request.Request(
        url, headers={'User-Agent': UA, 'Referer': 'https://www.linovelib.com/'})
    return urllib.request.urlopen(req, timeout=40).read().decode('utf-8', 'replace')


def main():
    s = post_search('实力至上')
    print('search len', len(s))
    for m in re.finditer('实力至上', s):
        frag = s[max(0, m.start() - 420):m.start() + 80].replace('\n', ' ')
        print('CTX', frag)
        break
    items = re.findall(r'href="(/novel/\d+\.html)"[^>]*>', s)
    print('novel links', items[:6])
    h = get('https://www.linovelib.com/novel/2139.html')
    print('book len', len(h))
    for pat in ['og:image', 'book-img', 'read_url']:
        m = re.search(re.escape(pat), h)
        if m:
            print('--', pat, '->', h[max(0, m.start() - 140):m.start() + 240].replace('\n', ' '))
    cu = re.search(r'og:novel:read_url" content="([^"]+)"', h)
    if cu:
        c = get(cu.group(1))
        print('catalog len', len(c))
        first = re.findall(r'<ul class="chapter-list[^"]*">(.*?)</ul>', c, re.S)[:1]
        if first:
            names = re.findall(r'<li[^>]*><a href="([^"]+)"[^>]*>([^<]+)</a>', first[0])
            print('first ul chapters:', names[:8])
        vols = re.findall(r'<h2><a href="([^"]+)"[^>]*>([^<]+)</a></h2>', c)
        print('volumes:', vols[:5])


main()
