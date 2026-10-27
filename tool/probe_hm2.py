import sys, re, requests
sys.stdout.reconfigure(encoding='utf-8')
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
s=requests.Session(); s.trust_env=False
s.headers.update({"User-Agent":UA,"Accept-Language":"zh-CN,zh;q=0.9"})
r=s.get("https://www.huanmengacg.com/index.php/book/info/6963", timeout=25)
h=r.text
open("tool/hm_book.html","w",encoding="utf-8").write(h)
hrefs=re.findall(r'href="([^"]+)"', h)
print("total hrefs", len(hrefs))
import collections
pat=collections.Counter(re.sub(r'\d+','N',x) for x in hrefs)
for k,v in pat.most_common(12): print(" ", v, k)
print("---- 含 6963 的链接:", [x for x in hrefs if '6963' in x][:10])
print("---- vol-group 片段:")
i=h.find('vol-group')
print(h[i-200:i+1200].replace("\n"," ")[:1400])
