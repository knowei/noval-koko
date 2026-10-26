import re
html = open("tool/ln_probe/eng_2013.html", encoding="utf-8", errors="replace").read()
for m in re.finditer(r'/novel/2013/catalog', html):
    s = max(0, m.start()-160)
    print(repr(html[s:m.end()+80]))
    print("---")
