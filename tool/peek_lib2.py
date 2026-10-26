import re
html = open("tool/ln_probe/lib_home.html", encoding="utf-8", errors="replace").read()
print("len", len(html))
for m in re.finditer(r"<form[^>]*>", html):
    print("FORM:", m.group(0))
for m in re.finditer(r"<input[^>]*>", html)[:0] if False else list(re.finditer(r"<input[^>]*>", html))[:12]:
    print("INPUT:", m.group(0))
for kw in ["searchkey", "search", "so.php", "s.php"]:
    idx = [m.start() for m in re.finditer(kw, html)][:5]
    print(kw, idx)
