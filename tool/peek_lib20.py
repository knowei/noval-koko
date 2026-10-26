import re
h = open("tool/ln_probe/lib_catalog.html", encoding="utf-8", errors="replace").read()
hrefs = re.findall(r'href="(/novel/2013/[^"]+)"', h)
print("total", len(hrefs), "unique", len(set(hrefs)))
for x in list(dict.fromkeys(hrefs))[:8]: print("  ", x)
print("textContent-ish ids:", re.findall(r'id="([^"]*(?:[Tt]ext|[Cc]ontent)[^"]*)"', h)[:10])
