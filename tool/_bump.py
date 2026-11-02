import io,re
p="pubspec.yaml"
s=io.open(p,encoding="utf-8").read()
s=s.replace("version: 0.7.1+8","version: 0.7.2+9")
io.open(p,"w",encoding="utf-8",newline="").write(s)
print([l for l in s.splitlines() if l.startswith("version")])
