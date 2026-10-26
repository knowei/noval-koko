# -*- coding: utf-8 -*-
import io
import re

h = io.open("tool/bz_getchapter.js", encoding="utf-8", errors="replace").read()
print("head 1200:\n", h[:1200])
for kw in ["async", "import(", "N=", "const N", "CryptoJS", "AES", "key"]:
    idxs = [m.start() for m in re.finditer(re.escape(kw), h)][:3]
    print("\n%s -> %s" % (kw, idxs))
    for i in idxs:
        print("   ", h[max(0, i - 150):i + 250].replace("\n", " "))
