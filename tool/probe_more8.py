import re
import urllib.parse
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')


def post(u, data, ref=None, enc='utf-8'):
    h = {'User-Agent': UA, 'Content-Type': 'application/x-www-form-urlencoded'}
    if ref:
        h['Referer'] = ref
    r = urllib.request.Request(u, data=data.encode('ascii'), headers=h)
    resp = urllib.request.urlopen(r, timeout=25)
    return resp.geturl(), resp.read().decode(enc, 'replace')


# a) sfacg 详情页里的 book-img 块（哪个才是本书封面）
b = open('tool/ln_probe/sfacg_book.html', encoding='utf-8', errors='replace').read()
for m in re.finditer(r'<div class="book-img">(.{0,220})', b, re.S):
    print('BOOKIMG', m.group(1).replace('\n', ' ')[:200])
i = b.find('class="book-title')
print('---- book-title block ----')
print(b[i:i + 900].replace('\n', ' ')[:900])

# b) sfacg 目录块
t = open('tool/ln_probe/sfacg_toc.html', encoding='utf-8', errors='replace').read()
j = t.find('catalog-list')
print('---- catalog block ----')
print(t[j - 200:j + 900].replace('\n', ' ')[:1100])

# c) sfacg 正文块
c = open('tool/ln_probe/sfacg_chap.html', encoding='utf-8', errors='replace').read()
k = c.find('article-content')
print('---- article-content ----')
print(c[k - 300:k + 600].replace('\n', ' ')[:900])

# d) 汉典古籍 搜索（EmpireCMS POST）
try:
    fin, body = post('https://gj.zdic.net/e/search/index.php',
                     'keyboard=' + urllib.parse.quote('西游记') + '&show=title&classid=0',
                     ref='https://gj.zdic.net/')
    print('ZDIC SEARCH', fin[:70], len(body), 'kwIn', '西游记' in body)
    open('tool/ln_probe/zdicgj_search.html', 'w', encoding='utf-8').write(body)
except Exception as e:  # noqa: BLE001
    print('ZDIC ERR', e)
