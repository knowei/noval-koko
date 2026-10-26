# -*- coding: utf-8 -*-
"""用已知明文前缀推 keystream，判断是不是重复密钥 XOR / RC4 / 分组密码。"""
import base64
import io
import json

p = json.load(io.open("tool/bz_payload.json", encoding="utf-8"))
raw = base64.b64decode(p + "=" * (-len(p) % 4))
decoded = json.load(io.open("tool/bz_decoded.json", encoding="utf-8"))
plain = json.dumps(decoded, separators=(",", ":")).encode("utf-8")
print("raw", len(raw), "plain(guess)", len(plain))
print("cipher head", raw[:16].hex())
print("plain head ", plain[:16].hex())

ks = bytes(c ^ k for c, k in zip(raw, plain))
print("keystream head:", ks[:40].hex())
print("keystream ascii:", "".join(chr(b) if 32 <= b < 127 else "." for b in ks[:60]))

# 找最短周期
for period in range(1, 65):
    ok = all(ks[i] == ks[i % period] for i in range(min(len(ks), 400)))
    if ok:
        print("repeat period:", period, ks[:period].hex())
        break
else:
    print("no small repeating period -> 非重复密钥 XOR（更像 RC4/分组密码）")

# 明文长度与密文长度的关系
print("len diff:", len(raw) - len(plain))
print("raw %16:", len(raw) % 16)
print("plain startswith:", plain[:80])
print("raw startswith 16-byte blocks (可能 IV):", raw[:16].hex())
