import re
html = open("tool/ln_probe/lib_book.html", encoding="utf-8", errors="replace").read()
for m in re.finditer(r'<a[^>]*class="[^"]*read-btn[^"]*"[^>]*>', html):
    print(m.group(0))
print("---all javascript:; anchors with class---")
for m in re.finditer(r'<a[^>]*href="javascript:;"[^>]*>', html)[:0] if False else list(re.finditer(r'<a[^>]*href="javascript:;"[^>]*>', html))[:6]:
    print(m.group(0))
