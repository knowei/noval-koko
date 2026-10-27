import sys, re
sys.stdout.reconfigure(encoding='utf-8')
h=open("tool/hm_book.html",encoding="utf-8").read()
print("=== forms ===")
for f in re.findall(r'<form[^>]*>', h): print(" ", f)
print("=== search inputs ===")
for m in re.finditer(r'<input[^>]*>', h):
    s=m.group(0)
    if 'search' in s.lower() or 'keyword' in s.lower() or 'name=' in s: print("  ", s[:160])
print("=== 搜索相关脚本/链接 ===")
for x in set(re.findall(r'[\'"]([^\'"]*search[^\'"]*)[\'"]', h)): print("  ", x[:120])
print()
h2=open("tool/hm_chap.html",encoding="utf-8").read()
print("=== 下一章/分页 ===")
for kw in ["下一章","下一頁","下一页","next_page","分页","page"]:
    idx=h2.find(kw)
    print(f"  {kw}: {idx}", (h2[max(0,idx-120):idx+80].replace('\n',' ') if idx>0 else ''))
