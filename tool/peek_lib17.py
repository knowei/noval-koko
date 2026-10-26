import re
for f in ["tool/ln_probe/eng_2013.html", "tool/ln_probe/eng_2601.html"]:
    html = open(f, encoding="utf-8", errors="replace").read()
    print("###", f, len(html))
    for m in re.finditer(r'<a[^>]*read-btn[^>]*>', html):
        print("  A:", m.group(0)[:200])
    print("  catalog hrefs:", re.findall(r'href="([^"]*catalog[^"]*)"', html)[:5])
    print("  /novel/x/ links:", re.findall(r'href="(/novel/\d+/[^"]+)"', html)[:5])
