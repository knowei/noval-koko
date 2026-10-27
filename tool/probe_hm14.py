import sys, re
sys.stdout.reconfigure(encoding='utf-8')
h=open("tool/hm_book.html",encoding="utf-8").read()
i=h.find('class="zhangjie-quanbu"')
seg=h[i:]
end=seg.find('<!--', 200)
seg=seg[:end if end>0 else 200000]
print("segment len:", len(seg))
print("li a count:", len(re.findall(r'<li>\s*<a href="/index\.php/book_read_6963', seg)))
print("ul count:", seg.count('<ul'), "vol-group count:", seg.count('vol-group'))
j=seg.find('vol-group')
print("--- vol area ---")
print(seg[max(0,j-500):j+900].replace("\n"," ")[:1200])
