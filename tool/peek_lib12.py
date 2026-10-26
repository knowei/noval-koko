import re
html = open("tool/ln_probe/lib_book.html", encoding="utf-8", errors="replace").read()
print("len", len(html))
i = html.find('<div class="book-layout')
if i < 0: i = html.find("book-detail")
print(html[max(0,i-200):i+2600])
