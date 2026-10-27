import sys, re, requests
sys.stdout.reconfigure(encoding='utf-8')
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
s=requests.Session(); s.trust_env=False
s.headers.update({"User-Agent":UA,"Accept-Language":"zh-CN,zh;q=0.9"})
r=s.get("https://www.huanmengacg.com/index.php/book/search?key="+requests.utils.quote("史莱姆"), headers={"Referer":"https://www.huanmengacg.com/"}, timeout=25)
r.encoding=r.apparent_encoding
h=r.text
open("tool/hm_search.html","w",encoding="utf-8").write(h)
i=h.find('/index.php/book/info/')
print(h[max(0,i-900):i+1500])
