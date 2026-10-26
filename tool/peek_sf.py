# -*- coding: utf-8 -*-
import io
import re

h = io.open("tool/sf_search.html", encoding="gbk", errors="replace").read()
print("chars:", len(h))
print("hrefs:")
for u in re.findall(r'href="([^"]+)"', h)[:30]:
    print("  ", u)
print("comic_cover count:", h.count("comic_cover"))
i = h.find("comic_cover")
if i > 0:
    print("--- around comic_cover ---")
    print(h[max(0, i - 300):i + 900])
j = h.find("\u7ed3\u679c")
print("--- around 结果 ---")
print(h[max(0, j - 200):j + 400] if j > 0 else "none")
print("--- tail ---")
print(h[-1500:])
