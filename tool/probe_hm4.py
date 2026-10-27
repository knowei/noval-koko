import sys, re
sys.stdout.reconfigure(encoding='utf-8')
h=open("tool/hm_chap.html",encoding="utf-8").read()
i=h.find('id="content"')
seg=h[i-300:i+2500]
print("=== around #content ===")
print(seg[:2800])
print("\n=== article tag ===")
j=h.find('<article')
print(h[j:j+700])
