import re

g = open('tool/ln_probe/gutenberg_book.html', encoding='utf-8', errors='replace').read()
print('PG h1', re.findall(r'<h1[^>]*>(.*?)</h1>', g, re.S)[:2])
print('PG h1 ctx', re.search(r'<h1[^>]*>.{0,200}', g, re.S).group(0)[:220] if '<h1' in g else None)
print('PG author', re.findall(r'itemprop="creator".{0,200}', g, re.S)[:2])

z = open('tool/ln_probe/zdicgj_search.html', encoding='utf-8', errors='replace').read()
i = z.find('/jibu/956/')
print('==== ZDIC item', z[max(0, i - 700):i + 300].replace('\n', ' ')[:900])

b = open('tool/ln_probe/zdic_book.html', encoding='utf-8', errors='replace').read()
j = b.find('/jibu/956/31311.html')
print('==== ZDIC book chapter ctx', b[max(0, j - 500):j + 200].replace('\n', ' ')[:700])
print('ZDIC bookdata', re.search(r'class="article-bookdata".{0,300}', b, re.S).group(0).replace('\n', ' ')[:300] if 'article-bookdata' in b else None)
