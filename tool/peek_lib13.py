import re
book = open("tool/ln_probe/lib_book.html", encoding="utf-8", errors="replace").read()
print("author link in book page:", re.findall(r'/authorarticle/[^"]+', book)[:3])
cat = open("tool/ln_probe/lib_catalog.html", encoding="utf-8", errors="replace").read()
print("catalog len", len(cat))
print("chapter-ish classes:", sorted(set(re.findall(r'class="(chapter[^"]*|section[^"]*|volume[^"]*|catalog[^"]*)"', cat)))[:20])
i = cat.find('class="chapter')
print(cat[max(0,i-800):i+700])
