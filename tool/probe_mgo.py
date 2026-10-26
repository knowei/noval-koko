# -*- coding: utf-8 -*-
"""探：m.bzmh.org/go 跳转端点是否返回明文图片列表；以及其它镜像站点。"""
import io
import re

import requests

UA = ("Mozilla/5.0 (Linux; Android 8.0; Pixel 2) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/94.0.4606.71 Mobile Safari/537.36")
H = {"User-Agent": UA}

s = requests.Session()
s.headers.update(H)
log = []


def say(x):
    log.append(str(x))
    print(str(x).encode("ascii", "replace").decode("ascii"))


urls = [
    "https://m.bzmh.org/go?token=8bbfbfa2bfacd82ccb532b&ms=133&cs=1643598&ct=x"
    "&host=https%3A%2F%2Fv2.apikk.top&from=https%3A%2F%2Fbaozimh.org%2F",
]
for u in urls:
    try:
        r = s.get(u, timeout=30, allow_redirects=True)
        say("%s -> %s final=%s bytes=%d" % (u[:60], r.status_code, r.url, len(r.content)))
        h = r.content.decode("utf-8", "replace")
        io.open("tool/bz_mgo.html", "w", encoding="utf-8").write(h)
        imgs = re.findall(r'<img[^>]+src="([^"]+)"', h)
        say("imgs=%d" % len(imgs))
        for i in imgs[:6]:
            say("  " + i)
        say("head: " + h[:200].replace("\n", " "))
    except Exception as e:  # noqa
        say("%s ERR %s" % (u[:60], e))

# 试探 webmota 镜像
for u in ["https://cn.webmota.com/", "https://cn.webmota.com/comic/chapter/133-6572120-302"]:
    try:
        r = s.get(u, timeout=25)
        say("%s -> %s bytes=%d" % (u, r.status_code, len(r.content)))
        h = r.content.decode("utf-8", "replace")
        say("  title: " + (re.search(r"<title>([\s\S]*?)</title>", h).group(1) if "<title>" in h else "none"))
    except Exception as e:  # noqa
        say("%s ERR %s" % (u, e))

io.open("tool/bz_mgo.txt", "w", encoding="utf-8").write("\n".join(log))
