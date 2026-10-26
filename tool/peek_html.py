import io
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "tool/bz_search.html"
h = io.open(path, encoding="utf-8", errors="replace").read()
print("file:", path, "chars:", len(h))
print("title:", re.findall(r"<title>(.*?)</title>", h, re.S)[:1])

for pat in [r'href="(/comic/[^"]+)"', r'href="(https?://[^"]*/comic/[^"]+)"']:
    got = re.findall(pat, h)
    print(pat, "->", len(got), got[:6])

# 找卡片候选
for cls in ["comics-card", "comic-card", "grid", "cover", "item"]:
    n = h.count(cls)
    if n:
        print(f"contains {cls}: {n}")

idx = h.find('href="/comic/')
if idx > 0:
    print("--- around first /comic/ link ---")
    print(h[max(0, idx - 500):idx + 900])
