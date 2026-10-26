# -*- coding: utf-8 -*-
import io
import re

h = io.open("tool/bz_chap.html", encoding="utf-8", errors="replace").read()
mods = sorted(set(re.findall(r'(/_nuxt/[A-Za-z0-9_.\-]*getChapter[A-Za-z0-9_.\-]*\.js)', h)))
out = io.StringIO()
out.write("modules: %s\n" % mods)
for m in set(re.findall(r'"([^"]*\.js)"', h)) and []:
    pass
io.open("tool/_g.txt", "w", encoding="utf-8").write(out.getvalue())
print("ok")
