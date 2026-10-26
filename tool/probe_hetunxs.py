import sys, urllib.request, urllib.parse

sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Linux; Android 8.0; Pixel 2) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/94.0.4606.71 Mobile Safari/537.36")

body = urllib.parse.urlencode(
    {"type": "articlename", "s": "黜龙", "submit": ""}).encode("gbk")
req = urllib.request.Request(
    "http://m.hetunxs.com/s.php", data=body,
    headers={
        "User-Agent": UA,
        "Referer": "http://m.hetunxs.com/",
        "Accept": "text/html,application/xhtml+xml,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9",
        "Content-Type": "application/x-www-form-urlencoded",
    })
raw = urllib.request.urlopen(req, timeout=25).read()
html = raw.decode("gbk", "replace")
print("len", len(html))
i = html.find('class="cover"')
print(html[max(0, i - 200):i + 900])
