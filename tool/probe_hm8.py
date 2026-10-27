import sys, re
sys.stdout.reconfigure(encoding='utf-8')
h=open("tool/hm_chap.html",encoding="utf-8").read()
# simulate JS extraction
i=h.find('<div id="content"')
j=h.find('</div>', h.find('data-c=', i))
box=h[i:h.find('<div id="text_control"', i) if '<div id="text_control"' in h[i:] else i+20000]
noise=re.search(r'data-c="([^"]+)"', h[i:i+400]).group(1)
print("noise class:", noise)
ps=re.findall(r'<p([^>]*)>(.*?)</p>', h[i:], re.S)
real=[]
for attrs, body in ps:
    if noise and ('class="%s"' % noise) in attrs: continue
    m=re.search(r'order:\s*(\d+)', attrs)
    o=int(m.group(1)) if m else 0
    t=re.sub(r'<[^>]+>','',body).replace('&nbsp;',' ').strip()
    real.append((o,t))
real.sort()
text="\n".join(t for _,t in real)
print("paras:", len(ps), "kept:", len(real), "chars:", len(text))
print(text[:400])
print("---- 末段:", text[-200:])
