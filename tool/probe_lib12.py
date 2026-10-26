"""查 book 8（欢迎来到实力至上主义的教室）：封面 markup + 目录结构。"""

import re
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')


def get(url):
    req = urllib.request.Request(
        url, headers={'User-Agent': UA, 'Referer': 'https://www.linovelib.com/'})
    return urllib.request.urlopen(req, timeout=40).read().decode('utf-8', 'replace')


def main():
    h = get('https://www.linovelib.com/novel/8.html')
    print('book len', len(h))
    m = re.search(r'<div class="book-img fl">(.{0,400})', h, re.S)
    print('BOOKIMG>', m.group(1).replace('\n', ' ') if m else 'NONE')
    m = re.search(r'og:image" content="([^"]+)"', h)
    print('OGIMAGE>', m.group(1) if m else 'NONE')

    c = get('https://www.linovelib.com/novel/8/catalog')
    print('catalog len', len(c))
    vol = re.findall(r'<h2><a href="([^"]+)"[^>]*>([^<]+)</a></h2>', c)
    print('volumes n=', len(vol), vol[:4])
    uls = re.findall(r'<ul class="chapter-list[^"]*">(.*?)</ul>', c, re.S)
    print('uls n=', len(uls))
    for i, u in enumerate(uls[:3]):
        ch = re.findall(r'<li[^>]*><a href="([^"]+)"[^>]*>([^<]+)</a>', u)
        print('UL%d' % i, 'n=', len(ch), ch[:6])


main()
