import sys
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Linux; Android 8.0; Pixel 2) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/94.0.4606.71 Mobile Safari/537.36")

urls = [
    "http://pic.hetunxs.com/image/168/168086/168086s.jpg",
    "https://pic.hetunxs.com/image/168/168086/168086s.jpg",
]

HEADER_SETS = [
    ("referer-m", {"User-Agent": UA, "Referer": "http://m.hetunxs.com/"}),
    ("referer-book",
     {"User-Agent": UA, "Referer": "http://m.hetunxs.com/book/168086.html",
      "Accept": "image/avif,image/webp,image/*,*/*;q=0.8"}),
]

for u in urls:
    for tag, headers in HEADER_SETS:
        try:
            req = urllib.request.Request(u, headers=headers)
            with urllib.request.urlopen(req, timeout=15) as r:
                data = r.read()
                print(tag, u, "→", r.status, len(data), "B",
                      r.headers.get("Content-Type"))
        except Exception as exc:  # noqa: BLE001
            print(tag, u, "→ 失败：", type(exc).__name__, exc)
