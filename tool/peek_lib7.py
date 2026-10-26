import re
html = open("tool/ln_probe/lib_home.html", encoding="utf-8", errors="replace").read()
for kw in ["S6", "searchkey", "t_frmsearch", "search"]:
    print("###", kw)
    for m in re.finditer(kw, html):
        s = max(0, m.start()-160); print("   ...", html[s:m.start()+220].replace("\n"," ")[:380])
        break
# find script tags referencing js files
print("### scripts")
for m in re.finditer(r'<script[^>]*src="([^"]+)"', html):
    print("  ", m.group(1))
