# -*- coding: utf-8 -*-
"""分析 tool/sf_toc.html：目录结构与分卷入口。"""
import io
import re

h = io.open("tool/sf_toc.html", encoding="utf-8", errors="replace").read()
print("len:", len(h))
print("catalog-list idx:", [m.start() for m in re.finditer("catalog-list", h)])
print("ChapterList/Volume hints:")
for kw in ["catalog", "Volume", "volume", "jsVolume", "章节", "\u76ee\u5f55", "data-id"]:
    print("  %-12s %d" % (kw, h.count(kw)))

i = h.find("catalog-list")
print("\n--- around catalog-list ---")
print(h[max(0, i - 500):i + 1200])

links = re.findall(r'href="(/Novel/[^"]+)"', h)
print("\nnovel links:", len(links))
for u in links:
    print("  ", u)

vols = re.findall(r'href="(/Novel/261860/\d+/)"', h)
print("\nvolume links:", len(vols), vols[:10])
