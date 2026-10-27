import sys, re
sys.stdout.reconfigure(encoding='utf-8')
h=open("tool/hm_book.html",encoding="utf-8").read()
for m in list(re.finditer(r'book_read_6963', h))[:6]:
    i=m.start()
    print("--- ctx:", h[max(0,i-260):i+160].replace("\n"," "))
print("\n=== TOC container search ===")
for key in ['id="chapterlist"','chapterlist','zhangjie-quanbu"','vol-group"','<ul','catalog']:
    j=h.find(key)
    print(f" {key}: {j}")
