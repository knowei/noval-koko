# -*- coding: utf-8 -*-
import io
import re

h = io.open("tool/sf_book.html", encoding="utf-8", errors="replace").read()
print("len:", len(h))
for kw in ["MainIndex", "catalog-list", "ChapterBody", "VIP", "vip",
           "\u5171", "\u7ae0", "\u8bd5\u8bfb", "\u5b57\u6570", "\u8fde\u8f7d"]:
    print("  %-12s %d" % (kw, h.count(kw)))
i = h.find("MainIndex")
print("\n--- around MainIndex ---")
print(h[max(0, i - 800):i + 800])
print("\n--- js hints ---")
for kw in ["ChapterList", "getChapter", "novelId", "/api", "ajax"]:
    for m in re.finditer(kw, h):
        s = max(0, m.start() - 120)
        print("[%s] %s" % (kw, h[s:m.start() + 160].replace("\n", " ")))
        break
