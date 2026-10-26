# -*- coding: utf-8 -*-
import io
import re

h = io.open("tool/bz_webmota.html", encoding="utf-8", errors="replace").read()
out = io.StringIO()
out.write("len: %d\n" % len(h))
out.write(h[:2500])
out.write("\n--- imgs ---\n")
for u in re.findall(r'<img[^>]+src="([^"]+)"', h)[:10]:
    out.write("  %s\n" % u)
out.write("--- scan ---\n")
for kw in ["api", "images", "data-ms", "script", "astro"]:
    for m in re.finditer(kw, h):
        out.write("[%s] %s\n" % (kw, h[max(0, m.start() - 120):m.start() + 200].replace("\n", " ")))
        break
io.open("tool/bz_wm_view.txt", "w", encoding="utf-8").write(out.getvalue())
print("ok")
