import re
for f in ["tool/ln_probe/lib_catalog.html","tool/ln_probe/lib_chap1.html"]:
    h = open(f, encoding="utf-8", errors="replace").read()
    print("###", f, len(h))
    m = re.search(r'<title>(.*?)</title>', h, re.S)
    print("  title:", (m.group(1).strip()[:80] if m else "n/a"))
    for kw in ["TextContent","chapter-list","read-content","cf-","challenge","Just a moment","人机","novel/2013/"]:
        print("   ", kw, h.count(kw))
