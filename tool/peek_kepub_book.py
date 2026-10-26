import io
import re

h = io.open('tool/kp_book_10044.html', encoding='utf-8').read()
out = []
out.append('len=%d' % len(h))
out.append('h1: %s' % re.findall(r'<h1[^>]*>(.*?)</h1>', h, re.S)[:3])
out.append('meta og: %s' % re.findall(r'<meta[^>]+(?:property|name)="(og:[^"]+)"[^>]+content="([^"]*)"', h)[:20])
out.append('chapter-list blocks: %d' % h.count('chapter-list'))
out.append('li anchors: %d' % len(re.findall(r'<li[^>]*>\s*<a[^>]+href="(/book/10044/\d+)"', h)))
m = re.search(r'<div[^>]*class="[^"]*chapter[^"]*"[^>]*>', h)
out.append('first chapter div: %s' % (m.group(0) if m else None))
# 抓一段章节列表附近 html
i = h.find('chapter-list')
if i > 0:
    out.append('around chapter-list:\n' + h[max(0, i - 300):i + 1200])
# 书籍信息区
j = h.find('book-info')
if j > 0:
    out.append('around book-info:\n' + h[max(0, j - 200):j + 900])
else:
    k = h.find('author')
    out.append('around author:\n' + h[max(0, k - 400):k + 700])
io.open('tool/kp_book_struct.txt', 'w', encoding='utf-8').write('\n\n'.join(out))
print('done')
