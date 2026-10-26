# -*- coding: utf-8 -*-
import io
import json

o = json.load(io.open("tool/bz_api2.json", encoding="utf-8"))
d = o["data"]
print("top keys:", list(o.keys()))
print("data keys:", list(d.keys()))
for k, v in d.items():
    if isinstance(v, (str, int, float)) and k != "desc":
        print("  %-14s %s" % (k, str(v)[:80]))
print("desc:", str(d.get("desc"))[:80])
ch = d.get("chapters") or []
print("chapters:", len(ch))
if ch:
    print("chapter[0] keys:", list(ch[0].keys()))
    print("chapter[0].attributes keys:", list(ch[0].get("attributes", {}).keys()))
    print("chapter[0]:", json.dumps(ch[0], ensure_ascii=False)[:400])
    print("chapter[-1]:", json.dumps(ch[-1], ensure_ascii=False)[:300])
