import re
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


def save(tag, u, f, ref=None):
    try:
        fin, b = get(u, ref, )
    except Exception as e:  # noqa: BLE001
        print('%-16s ERR %s' % (tag, e))
        return ''
    open('tool/ln_probe/' + f, 'w', encoding='utf-8').write(b)
    print('%-16s %s len=%d' % (tag, fin[:70], len(b)))
    return b


# Gutenberg 全文页
b = save('pg-full', 'https://www.gutenberg.org/cache/epub/1342/pg1342-images.html',
         'pg1342.html')
if b:
    print('  div.chapter', len(re.findall(r'<div class="chapter"', b)))
    print('  h2', re.findall(r'<h2[^>]*>(.*?)</h2>', b, re.S)[:5])
    i = b.find('<body')
    print('  body ctx', b[i:i + 400].replace('\n', ' '))

# SF轻小说 目录页
b = save('sfacg-toc', 'https://book.sfacg.com/Novel/758795/MainIndex/',
         'sfacg_toc.html')
if b:
    print('  chapter links',
          re.findall(r'href="(/Novel/758795/\d+[^"]*)"', b)[:5])
    print('  classes', sorted(set(re.findall(r'class="([^"]+)"', b)))[:22])

# SF轻小说 详情页字段
b = open('tool/ln_probe/sfacg_book.html', encoding='utf-8', errors='replace').read()
for pat in (r'class="book-name"[^>]*>(.*?)<', r'class="author-name"[^>]*>(.*?)<',
            r'class="autor-name"[^>]*>(.*?)<', r'class="book-summary"[^>]*>(.*?)</div>',
            r'class="book-img"[^>]*>\s*<img[^>]*src="([^"]+)"'):
    m = re.search(pat, b, re.S)
    print('FIELD', pat[:34], '->', (m.group(1).strip()[:80] if m else None))
