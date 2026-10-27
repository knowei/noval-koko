import sys, re
sys.stdout.reconfigure(encoding='utf-8')
h=open("tool/hm_book.html",encoding="utf-8").read()
# print the info block area
i=h.find('style_h1')
print("=== book info block ===")
print(re.sub(r'\n\s*\n','\n', h[max(0,i-1500):i+2500])[:3500])
