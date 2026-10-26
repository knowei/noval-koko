import io
import re

h = io.open("tool/bz_chapjs.js", encoding="utf-8", errors="replace").read()
print("chars:", len(h))
urls = sorted(set(re.findall(r"https?://[^\"'`\s)]+", h)))
print("urls:")
for u in urls:
    if "apikk" in u or "/api" in u or "6wm" in u:
        print("  ", u)
print("\nfetch calls:")
for m in re.findall(r"fetch\((.{0,160}?)\)", h)[:10]:
    print("  ", m)
print("\nkey words:")
for kw in ["chapter", "images", "getChapter", "v2.apikk", "mode=", "mid=", "cid="]:
    print(f"  {kw}: {h.count(kw)}")
i = h.find("fetch(")
print("\n--- around first fetch ---")
print(h[max(0, i - 600):i + 700])
