# -*- coding: utf-8 -*-
"""把 sample_sources/baozimh.json 并入 docs/live_sources.json（同名替换）。"""
import io
import json

src = json.load(io.open("sample_sources/baozimh.json", encoding="utf-8"))
path = "docs/live_sources.json"
cur = json.load(io.open(path, encoding="utf-8"))

name = src["bookSourceName"]
cur = [s for s in cur if s.get("bookSourceName") != name]
cur.append(src)
io.open(path, "w", encoding="utf-8").write(
    json.dumps(cur, ensure_ascii=False, indent=2)
)
print("sources:", len(cur), "->", [s.get("bookSourceName") for s in cur])
