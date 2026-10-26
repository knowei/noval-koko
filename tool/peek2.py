import io, re, sys

p = sys.argv[1] if len(sys.argv) > 1 else 'tool/ln_probe/r_kakuyomu.html'
t = io.open(p, encoding='utf-8', errors='ignore').read()
print('len', len(t))
works = sorted(set(re.findall(r'/works/(\d{6,})', t)))
print('work ids:', len(works), works[:10])
titles = re.findall(r'data-testid="[^"]*title[^"]*"[^>]*>([^<]{2,60})', t)
print('titles by testid:', len(titles), titles[:6])
h2 = re.findall(r'<h[23][^>]*>([^<]{2,60})</h[23]>', t)
print('h2/h3:', len(h2), h2[:10])
# 找 JSON 数据块
for marker in ('__NEXT_DATA__', 'application/ld+json', 'window.__', 'apollo'):
    i = t.find(marker)
    print(marker, i)
i = t.find('スライム')
print('--- ctx around スライム ---')
print(t[max(0, i - 600):i + 400])
