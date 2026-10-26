import re
import urllib.parse
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')


def save(tag, u, f, ref=None):
    h = {'User-Agent': UA}
    if ref:
        h['Referer'] = ref
    try:
        r = urllib.request.Request(u, headers=h)
        resp = urllib.request.urlopen(r, timeout=25)
        b = resp.read().decode('utf-8', 'replace')
    except Exception as e:  # noqa: BLE001
        print('%-18s ERR %s' % (tag, e))
        return ''
    open('tool/ln_probe/' + f, 'w', encoding='utf-8').write(b)
    print('%-18s %s len=%d' % (tag, resp.geturl()[:70], len(b)))
    return b


# 1) SF轻小说 正文页
b = save('sfacg-chap', 'https://book.sfacg.com/Novel/758795/1005748/9350352/',
         'sfacg_chap.html', ref='https://book.sfacg.com/Novel/758795/MainIndex/')
if b:
    print('  title', re.findall(r'<title>(.*?)</title>', b)[:1])
    print('  classes', sorted(set(re.findall(r'class="([^"]+)"', b)))[:25])

# 2) 详情页封面
b = open('tool/ln_probe/sfacg_book.html', encoding='utf-8', errors='replace').read()
for pat in (r'<div class="book-img">(.{0,300})', r'class="book-title(.{0,200})'):
    m = re.search(pat, b, re.S)
    print('SF', pat[:22], '->', (m.group(1).replace('\n', ' ')[:260] if m else None))

# 3) 汉典古籍 搜索
g = open('tool/ln_probe/zdicgj2.html', encoding='utf-8', errors='replace').read()
for m in re.finditer(r'<form[^>]*>', g):
    print('ZDIC FORM', m.group(0)[:200])
for m in re.finditer(r'<input[^>]*>', g):
    s = m.group(0)
    if re.search('search|key|word|kw|q"', s, re.I):
        print('ZDIC INPUT', s[:160])
for m in set(re.findall(r'action="([^"]+)"', g)):
    print('ZDIC ACTION', m)

# 4) 天涯在线书库 搜索表单
t = open('tool/ln_probe/tianyabooks.html', encoding='utf-8', errors='replace').read()
for m in re.finditer(r'<form[^>]*>', t):
    print('TY FORM', m.group(0)[:200])
for m in set(re.findall(r'action="([^"]+)"', t)):
    print('TY ACTION', m)
