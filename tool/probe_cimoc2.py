import sys, json
sys.stdout.reconfigure(encoding='utf-8')
d=json.load(open("tool/cimoc_bases.json",encoding="utf-8"))
print("entries:", len(d))
hosts={}
for k,v in d.items():
    u=(v or {}).get("baseUrl") or ""
    hosts.setdefault(u, []).append(k)
print("unique baseUrl:", len(hosts))
for u,ks in list(hosts.items())[:10]:
    print(" ", u, ks)
