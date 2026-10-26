import re
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')


def grab(u, f):
    r = urllib.request.Request(u, headers={'User-Agent': UA})
    resp = urllib.request.urlopen(r, timeout=25)
    b = resp.read().decode('utf-8', 'replace')
    open('tool/ln_probe/' + f, 'w', encoding='utf-8').write(b)
    print(u[:70], '->', resp.geturl()[:70], len(b))
    return b


b = grab('https://gj.zdic.net/jibu/956/', 'zdic_book.html')
print('h1/h2', re.findall(r'<h[12][^>]*>(.*?)</h[12]>', b, re.S)[:4])
links = re.findall(r'href="(/jibu/956/\d+[^"]*)"[^>]*>(.{0,40}?)</a>', b, re.S)
print('chapter links', len(links), links[:5])
print('classes', sorted(set(re.findall(r'class="([^"]+)"', b)))[:28])
