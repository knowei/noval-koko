import io
import re
import sys


def load(p):
    return io.open(p, encoding="utf-8", errors="replace").read()


h = load("tool/bz_manga.html")

print("== title/h1 ==")
for m in re.findall(r"<h1[^>]*>(.*?)</h1>", h, re.S)[:3]:
    print("  h1:", " ".join(m.split())[:120])

print("\n== img tags (first 6) ==")
for m in re.findall(r"<img[^>]*>", h)[:6]:
    print("  ", m[:220])

print("\n== intro-ish classes ==")
for cls in ["comic-detail", "detail", "intro", "description", "synopsis", "author"]:
    n = h.count(cls)
    if n:
        print(f"  {cls}: {n}")

i = h.find("/chapterlist/")
print("\n--- around /chapterlist/ ---")
print(h[max(0, i - 400):i + 600])

print("\n== chapter link samples ==")
chaps = re.findall(r'href="(/manga/[^"]+/\d+[^"]*)"', h)
print("count:", len(chaps), chaps[:6])

print("\n== text-ish meta ==")
for pat in [r'<meta[^>]*(?:og:|description)[^>]*>']:
    for m in re.findall(pat, h)[:6]:
        print("  ", m[:200])
