import re
html = open("tool/ln_probe/lib_chap2.html", encoding="utf-8", errors="replace").read()
b = html.find("<body")
body = html[b:]
print("body len", len(body))
print("next page:", [m for m in re.findall(r'(下一页|下页|_2\.html|readpage)', body)][:6])
# find divs with ids
print("ids:", re.findall(r'<div[^>]*id="([^"]+)"', body)[:20])
print("classes:", sorted(set(re.findall(r'<div[^>]*class="([^"]+)"', body)))[:25])
i = body.find("<p>")
print(body[max(0,i-700):i+300])
