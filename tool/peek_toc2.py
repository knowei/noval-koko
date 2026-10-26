import io
import re

h = io.open("tool/bz_toc.html", encoding="utf-8", errors="replace").read()
srcs = re.findall(r'<script[^>]*src="([^"]+)"', h)
print("scripts:")
for s in srcs:
    print("  ", s)

mods = re.findall(r'type="module"[^>]*', h)
print("\nmodule count:", len(mods))
for m in mods[:10]:
    print("  ", m[:160])

# 找 Alpine 组件里的 fetch 路径
for pat in [r'["\']([^"\']*wtako[^"\']*)["\']', r'["\']([^"\']*\.6wm\.top[^"\']*)["\']', r"(/api/[A-Za-z0-9_\-/]+)"]:
    print(pat, "->", sorted(set(re.findall(pat, h)))[:10])
