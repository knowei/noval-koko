h = open("tool/ln_probe/lib_ref1.html", encoding="utf-8", errors="replace").read()
i = h.find("TextContent")
print(repr(h[i-200:i+400]))
print("=== pagination ===")
for kw in ["mlfy_page","下一页","_2.html","pb_next","page_chapter"]:
    j = h.find(kw)
    print(kw, j, repr(h[max(0,j-120):j+160]) if j>0 else "")
