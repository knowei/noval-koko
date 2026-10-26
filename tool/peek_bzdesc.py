# -*- coding: utf-8 -*-
import io
import re

h = io.open("tool/bz_manga2.html", encoding="utf-8", errors="replace").read()
print("len:", len(h))
# 找简介容器：包含「唐三因偷学」的标签上下文
key = "\u5510\u4e09\u56e0\u5077\u5b66"
idx = h.find(key)
print("desc at:", idx)
while idx > 0:
    s = max(0, idx - 700)
    print("=== context ===")
    print(h[s:idx + 120].replace("\n", " "))
    break
print("\n--- candidate containers ---")
for pat in [r'<div class="prose[^"]*"', r'<p class="[^"]*text[^"]*"', r'id="description"',
            r'class="[^"]*desc[^"]*"', r'<div class="[^"]*intro[^"]*"']:
    for m in re.finditer(pat, h):
        print(pat, "->", h[m.start():m.start() + 200].replace("\n", " ")[:200])
        break
