import io
import re

h = io.open("tool/bz_toc.html", encoding="utf-8", errors="replace").read()
print("chars:", len(h))
print("chapter mentions:", h.count("chapter"))
print("links with digits:", re.findall(r'href="(/manga/[^"]*?/[0-9][^"]*)"', h)[:5])
for m in sorted(set(re.findall(r'["\'](/api/[^"\']+)["\']', h)))[:20]:
    print("api:", m)
# 找内联 script 里的数据
for m in re.findall(r'<script[^>]*>(.{0,400}?)</script>', h, re.S)[:6]:
    s = " ".join(m.split())
    if s:
        print("script:", s[:300])
i = h.find("chapter")
print("--- around first 'chapter' ---")
print(h[max(0, i - 300):i + 700])
