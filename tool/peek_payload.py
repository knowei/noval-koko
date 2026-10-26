# -*- coding: utf-8 -*-
import base64
import io
import json

p = json.load(io.open("tool/bz_payload.json", encoding="utf-8"))
print("len:", len(p))
raw = base64.b64decode(p + "=" * (-len(p) % 4))
print("bytes:", len(raw))
print("first 80 hex:", raw[:80].hex())
printable = sum(1 for b in raw if 32 <= b < 127)
print("printable ratio: %.2f" % (printable / max(1, len(raw))))
print("as text head:", raw[:120])

# 尝试常见的简单 XOR：用固定单字节
best = None
for k in range(1, 256):
    dec = bytes(b ^ k for b in raw)
    pr = sum(1 for b in dec if 32 <= b < 127 or b in (10, 13)) / max(1, len(dec))
    if best is None or pr > best[1]:
        best = (k, pr, dec)
print("best xor key %d ratio %.2f" % (best[0], best[1]))
print("sample:", best[2][:160])
