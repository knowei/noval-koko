import re, collections
html = open("tool/ln_probe/lib_home.html", encoding="utf-8", errors="replace").read()
hrefs = re.findall(r'href="([^"]+)"', html)
c = collections.Counter()
for h in hrefs:
    c[re.sub(r'\d+', 'N', h)] += 1
for k, v in c.most_common(40):
    print(v, k)
