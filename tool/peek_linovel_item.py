import io
import sys

sys.stdout.reconfigure(encoding="utf-8")
h = io.open("tool/ln_probe/search_linovel.html", encoding="utf-8").read()
i = h.find("search-book")
print(h[i - 120:i + 1500])
