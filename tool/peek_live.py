import json
srcs = json.load(open("docs/live_sources.json", encoding="utf-8"))
for s in srcs:
    print(s.get("bookSourceName"), "|", s.get("bookSourceUrl"), "| header:", str(s.get("header"))[:200])
    print("   toc:", json.dumps(s.get("ruleToc"), ensure_ascii=False)[:300])
