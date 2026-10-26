# -*- coding: utf-8 -*-
"""找 getChapter.js 里解码 chapterImages 的函数（c as M）。"""
import io

h = io.open("tool/bz_getchapter.js", encoding="utf-8", errors="replace").read()
print("chars:", len(h))
for kw in ["exit", "fromCharCode", "atob", "JSON.parse", "images", "split", "reverse"]:
    print("  %-14s %d" % (kw, h.count(kw)))

# 打印导出映射与疑似解码函数
i = h.find("export")
print("\n--- exports ---")
print(h[i:i + 400] if i >= 0 else "none")

for kw in ["fromCharCode", "images"]:
    j = h.find(kw)
    while j >= 0:
        print("\n=== around %s @%d ===" % (kw, j))
        print(h[max(0, j - 700):j + 700])
        break
