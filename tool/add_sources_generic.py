# -*- coding: utf-8 -*-
"""把若干 sample_sources/*.json 并入 docs/live_sources.json（同名替换）。

用法：python tool/add_sources_generic.py bzmh
      python tool/add_sources_generic.py bzmh baozimh   # 多个
"""
import io
import json
import sys

path = "docs/live_sources.json"
cur = json.load(io.open(path, encoding="utf-8"))

keys = sys.argv[1:] or ["bzmh"]
for key in keys:
    src = json.load(io.open(f"sample_sources/{key}.json", encoding="utf-8"))
    name = src["bookSourceName"]
    cur = [s for s in cur if s.get("bookSourceName") != name]
    cur.append(src)
    print("merged", key, "->", name)

io.open(path, "w", encoding="utf-8").write(
    json.dumps(cur, ensure_ascii=False, indent=2)
)
print("total sources:", len(cur))
for s in cur:
    print("  -", s.get("bookSourceGroup"), s.get("bookSourceName"))
