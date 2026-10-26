# -*- coding: utf-8 -*-
import io
import re

s = io.open("tool/bz_decoder.js", encoding="utf-8", errors="replace").read()
print("chars:", len(s))
for kw in ["crypto", "subtle", "atob", "btoa", "TextDecoder", "TextEncoder",
           "__cimg", "Uint8Array", "decrypt", "fromCharCode", "charCodeAt",
           "document", "navigator", "JSON.parse", "split"]:
    print("  %-12s %d" % (kw, s.count(kw)))
i = s.find("__cimg")
print("\n--- around __cimg ---")
print(s[max(0, i - 500):i + 500] if i >= 0 else "none")
