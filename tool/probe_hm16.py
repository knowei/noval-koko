import sys, re, requests
sys.stdout.reconfigure(encoding='utf-8')
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
s=requests.Session(); s.trust_env=False
s.headers.update({"User-Agent":UA,"Accept-Language":"zh-CN,zh;q=0.9"})
r=s.get("https://www.huanmengacg.com/index.php/book/info/6963", timeout=25)
r.encoding=r.apparent_encoding
h=r.text
open("tool/hm_book2.html","w",encoding="utf-8").write(h)
i=h.find('class="zhangjie-quanbu"')
seg=h[i:i+6000]
links=re.findall(r'<a href="(/index\.php/book_read_6963_\d+\.html)"[^>]*>(.*?)</a>', seg, re.S)
print("TOC li links in zhangjie-quanbu:", len(links))
for u,t in links: print(" ", u.split('_')[-1].replace('.html',''), re.sub(r'<[^>]+>','',t).strip())
