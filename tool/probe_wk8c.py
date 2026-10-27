import sys, re, requests
sys.stdout.reconfigure(encoding='utf-8')
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
s=requests.Session(); s.trust_env=False
s.headers.update({"User-Agent":UA,"Accept-Language":"zh-CN,zh;q=0.9"})
r=s.get("https://www.wenku8.net/modules/article/search.php?searchkey="+requests.utils.quote("妹妹人生".encode("gbk")),
        headers={"Referer":"https://www.wenku8.net/"}, timeout=20)
r.encoding=r.apparent_encoding
t=re.sub(r'\s+',' ',re.sub(r'<[^>]+>',' ',r.text))
print("== wenku8 search plain:", t[:400])
print("  forms:", re.findall(r'<form[^>]*>', r.text)[:3])
print("  inputs:", re.findall(r'<input[^>]*name="([^"]+)"[^>]*>', r.text)[:6])
