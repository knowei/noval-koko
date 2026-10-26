import io
import re
import sys
from collections import Counter

path = sys.argv[1] if len(sys.argv) > 1 else "tool/bz_search.html"
h = io.open(path, encoding="utf-8", errors="replace").read()

hrefs = re.findall(r'href="([^"]+)"', h)
cnt = Counter()
for u in hrefs:
    key = re.sub(r"[0-9a-zA-Z\-_]{6,}", "{id}", u)
    cnt[key] += 1
print("top href patterns:")
for k, v in cnt.most_common(15):
    print(f"  {v:4d}  {k}")

print("\napi mentions:")
for m in sorted(set(re.findall(r'["\'](/?api/[^"\']+)["\']', h)))[:20]:
    print("  ", m)

print("\nother endpoint-ish:")
for m in sorted(set(re.findall(r'["\'](/[a-z0-9\-]+/[^"\']{0,40})["\']', h)))[:25]:
    print("  ", m)

i = h.find('class="comics-card')
if i < 0:
    i = h.find("grid")
print("\n--- sample block ---")
print(h[max(0, i - 300):i + 1500])
