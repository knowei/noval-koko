import io
import re

h = io.open("tool/bz_chap.html", encoding="utf-8", errors="replace").read()
print("chars:", len(h))
print("scripts:", re.findall(r'<script[^>]*src="([^"]+)"', h)[:8])
print("img count:", len(re.findall(r"<img", h)))
for m in re.findall(r"<img[^>]*>", h)[:6]:
    print("  img:", m[:220])
print("\napis:", sorted(set(re.findall(r"https?://[a-z0-9.\-]+/api/[A-Za-z0-9_\-/]*", h)))[:10])
print("\ndata attrs:", sorted(set(re.findall(r'data-[a-z\-]+="[^"]{0,60}"', h)))[:20])
i = h.find("chapter")
print("\n--- around 'data-' block ---")
j = h.find("x-data")
print(h[max(0, j - 200):j + 800])
