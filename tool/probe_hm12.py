import sys, re
sys.stdout.reconfigure(encoding='utf-8')
h=open("tool/hm_book.html",encoding="utf-8").read()
idxs=[m.start() for m in re.finditer(r'book_read_6963', h)]
print("occurrences:", len(idxs))
i=idxs[2] if len(idxs)>2 else idxs[0]
print(h[max(0,i-1200):i+500].replace("\n"," ")[:1700])
