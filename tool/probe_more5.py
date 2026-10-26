import re
import urllib.parse
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')


def get(u, ref=None, enc='utf-8'):
    h = {'User-Agent': UA}
    if ref:
        h['Referer'] = ref
    r = urllib.request.Request(u, headers=h)
    resp = urllib.request.urlopen(r, timeout=25)
    return resp.geturl(), resp.read().decode(enc, 'replace')


def dump(tag, u, save, enc='utf-8'):
    try:
        fin, b = get(u, enc=enc)
    except Exception as e:  # noqa: BLE001
        print('%-14s ERR %s' % (tag, e))
        return ''
    open('tool/ln_probe/' + save, 'w', encoding='utf-8').write(b)
    print('%-14s %s len=%d' % (tag, fin[:70], len(b)))
    return b


# SF轻小说：详情页 / 目录 / 正文
d = dump('sfacg-book', 'https://book.sfacg.com/Novel/758795', 'sfacg_book.html')
if d:
    for pat in (r'<h1[^>]*>(.*?)</h1>', r'class="[^"]*(?:bookname|BookName|author|Author)[^"]*"[^>]*>'):
        pass
    print('  h1', re.findall(r'<h1[^>]*>(.*?)</h1>', d, re.S)[:1])
    print('  catalog-links',
          re.findall(r'href="([^"]*(?:Catalog|Index|catalog|index)[^"]*)"', d)[:6])
    print('  classes', sorted(set(re.findall(r'class="([^"]+)"', d)))[:20])

# Project Gutenberg：搜索页条目结构
g = open('tool/ln_probe/gutenberg.html', encoding='utf-8', errors='replace').read()
i = g.find('booklink')
print('gutenberg booklink ctx:', g[max(0, i - 200):i + 500].replace('\n', ' ')[:700])
d = dump('gutenberg-book', 'https://www.gutenberg.org/ebooks/1342', 'gutenberg_book.html')
if d:
    print('  title', re.findall(r'<title>(.*?)</title>', d)[:1])
    print('  html-link', re.findall(r'href="([^"]*(?:1342-h|1342\.txt|files)[^"]*)"', d)[:6])
