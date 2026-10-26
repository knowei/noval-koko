# -*- coding: utf-8 -*-
import io

s = io.open("tool/bz_decoder.js", encoding="utf-8", errors="replace").read()
out = io.StringIO()
for msg in ["x0", "x1", "x3", "x4"]:
    for pat in ["'%s'" % msg, '"%s"' % msg]:
        i = s.find(pat)
        if i >= 0:
            out.write("== %s at %d\n%s\n\n" % (pat, i, s[max(0, i - 700):i + 120]))
            break
io.open("tool/_e0.txt", "w", encoding="utf-8").write(out.getvalue())
print("ok")
