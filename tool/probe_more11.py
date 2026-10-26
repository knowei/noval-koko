import re
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')

r = urllib.request.Request('https://gj.zdic.net/jibu/956/31311.html',
                           headers={'User-Agent': UA,
                                    'Referer': 'https://gj.zdic.net/jibu/956/'})
resp = urllib.request.urlopen(r, timeout=25)
b = resp.read().decode('utf-8', 'replace')
open('tool/ln_probe/zdic_chap.html', 'w', encoding='utf-8').write(b)
print('len', len(b))
i = b.find('article-body')
print('CTX', b[max(0, i - 300):i + 1200].replace('\n', ' ')[:1400])
