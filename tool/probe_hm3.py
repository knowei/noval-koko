import sys, re, requests, collections
sys.stdout.reconfigure(encoding='utf-8')
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
def g(u, ref=None):
    s=requests.Session(); s.trust_env=False
    h={"User-Agent":UA,"Accept-Language":"zh-CN,zh;q=0.9"}
    if ref: h["Referer"]=ref
    r=s.get(u, headers=h, timeout=25); r.encoding=r.apparent_encoding
    return r
def plain(h): return re.sub(r'\s+',' ',re.sub(r'<[^>]+>',' ',h)).strip()

u="https://www.huanmengacg.com/index.php/book_read_6963_3206.html"
r=g(u, ref="https://www.huanmengacg.com/index.php/book/info/6963"); h=r.text
open("tool/hm_chap.html","w",encoding="utf-8").write(h)
t=re.search(r'<title>(.*?)</title>', h, re.S)
print("chap:", r.status_code, len(r.content), t.group(1).strip() if t else '?')
for sel in ['id="content"','class="content"','id="chaptercontent"','id="txt"','class="txt"','id="booktxt"','read-content','id="nr1"','article']:
    if sel in h: print("  hit:", sel, h.count(sel))
ids=re.findall(r'<div[^>]*id="([^"]+)"', h)
print("  div ids:", collections.Counter(ids).most_common(12))
print("  text:", plain(h)[:300])
print("  next links:", re.findall(r'href="(/index\.php/book_read_6963_\d+\.html)"[^>]*>([^<]{1,8})</a>', h)[:5])
print("### search")
for kw in ["妹妹人生","剑来"]:
    for u2 in ["https://www.huanmengacg.com/index.php/search?keyword=",
               "https://www.huanmengacg.com/index.php/search/index?keyword=",
               "https://www.huanmengacg.com/index.php/book/search?keyword="]:
        try:
            rr=g(u2+requests.utils.quote(kw))
            n=len(re.findall(r'/index\.php/book/info/\d+', rr.text))
            print("  %s%s -> %s %dB books=%d" % (u2, kw, rr.status_code, len(rr.content), n))
        except Exception as e:
            print("  ERR", u2, type(e).__name__, str(e)[:50])
