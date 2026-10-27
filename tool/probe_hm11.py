import sys, re
sys.stdout.reconfigure(encoding='utf-8')
h=open("tool/hm_book.html",encoding="utf-8").read()
i=h.find('zhangjie-quanbu')
print("zhangjie idx:", i)
seg=h[i:i+2500]
print(seg.replace("\n"," ")[:2500])
