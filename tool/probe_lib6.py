import urllib.request, urllib.parse, http.cookiejar, gzip
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
cj = http.cookiejar.CookieJar()
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        print("  REDIRECT", code, newurl)
        return None
op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj), NoRedirect)
op.addheaders = [("User-Agent", UA), ("Accept-Language", "zh-CN,zh;q=0.9")]
def call(u, data=None, ref=None):
    h = {"Referer": ref or u, "Accept": "text/html,*/*"}
    body = urllib.parse.urlencode(data).encode() if data else None
    if body: h["Content-Type"] = "application/x-www-form-urlencoded"
    r = urllib.request.Request(u, data=body, headers=h)
    try:
        resp = op.open(r, timeout=25)
        raw = resp.read()
        if resp.headers.get("Content-Encoding") == "gzip": raw = gzip.decompress(raw)
        print("  status", resp.status, "len", len(raw), "loc", resp.headers.get("Location"))
        return raw, resp
    except urllib.error.HTTPError as e:
        raw = e.read()
        print("  HTTPError", e.code, "len", len(raw), "loc", e.headers.get("Location"))
        return raw, e
    except Exception as e:
        print("  ERR", e)
        return b"", None

print("home:")
call("https://www.linovelib.com/")
print("cookies:", [c.name for c in cj])
print("S6 post:")
raw, resp = call("https://www.linovelib.com/S6/", data={"searchkey": "史莱姆"}, ref="https://www.linovelib.com/")
print("body head:", raw[:400].decode("utf-8","replace").replace("\n"," "))
