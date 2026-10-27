import json, sys, io
sys.stdout.reconfigure(encoding='utf-8')
live=json.load(open("docs/live_sources.json",encoding="utf-8"))
new=json.load(open("sample_sources/bigee.json",encoding="utf-8"))
live=[s for s in live if s.get("bookSourceName")!=new["bookSourceName"]]
live.append(new)
json.dump(live, open("docs/live_sources.json","w",encoding="utf-8"), ensure_ascii=False, indent=2)
print("live sources:", len(live), [s["bookSourceName"] for s in live])
