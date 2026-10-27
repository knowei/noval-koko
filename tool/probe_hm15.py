import sys, re
sys.stdout.reconfigure(encoding='utf-8')
h=open("tool/hm_book.html",encoding="utf-8").read()
pairs=re.findall(r'<a href="/index\.php/book_read_6963_(\d+)\.html"[^>]*>(.*?)</a>', h, re.S)
seen={}
for cid,t in pairs:
    t=re.sub(r'<[^>]+>','',t).strip()
    if cid not in seen: seen[cid]=t
print("unique chapters:", len(seen))
for cid,t in list(seen.items()):
    print(" ", cid, t)
