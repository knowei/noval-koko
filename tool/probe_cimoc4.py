import sys, json, re
from urllib.parse import urlparse
sys.stdout.reconfigure(encoding='utf-8')
res=json.load(open("tool/cimoc_probe.json",encoding="utf-8"))
PLACEHOLDER=("welcome","站点创建成功","baidu","百度一下","redirecting","unsupported language","")
def host(u):
    try: return urlparse(u).netloc.lower()
    except: return u
A=[];B=[];C=[]
for r in res:
    if r["ok"] and r["status"]<400:
        t=(r["title"] or "").strip()
        low=t.lower()
        if r["bytes"]>=8000 and low not in PLACEHOLDER and not any(p and p in low for p in ("welcome","站点创建成功","百度一下","redirecting","unsupported language")):
            A.append(r)
        else: B.append(r)
    else: C.append(r)
# 去重（同 host 合并别名）
groups={}
for r in A: groups.setdefault(host(r["base"]), []).append(r)
lines=[]
lines.append("# Cimoc 源站可达性体检（2026-10-27）\n")
lines.append(f"原始 JSON：`sourceBaseUrl.json`（{len(res)} 个条目）\n")
lines.append(f"- **A 类：可达且看起来是真站 —— {len(groups)} 个域名（{len(A)} 个 key）**")
lines.append(f"- B 类：可达但像占位页/纯 API —— {len(B)} 个 key")
lines.append(f"- C 类：不可达 —— {len(C)} 个 key\n")
lines.append("## A 类：可达的真站（按域名去重）\n")
lines.append("| 域名 | key | 标题 | 大小 | 耗时 | 跳转后 |")
lines.append("|---|---|---|---|---|---|")
for h,rs in sorted(groups.items(), key=lambda kv: kv[0]):
    r=rs[0]
    keys="/".join(x["key"] for x in rs)
    same = "" if r["final"].rstrip("/")==r["base"].rstrip("/") else r["final"]
    lines.append(f"| {h} | {keys} | {r['title'][:24]} | {r['bytes']//1024}KB | {r['ms']}ms | {same[:46]} |")
lines.append("\n## B 类：可达但疑似占位 / 纯接口（不建议直接对接）\n")
lines.append("| key | 域名 | 现象 |")
lines.append("|---|---|---|")
for r in sorted(B,key=lambda x:x["key"]):
    lines.append(f"| {r['key']} | {r['base'][:46]} | {r['status']} / {r['bytes']}B / {r['title'][:20] or '(无标题)'} |")
lines.append("\n## C 类：不可达\n")
lines.append("| key | 域名 | 原因 |")
lines.append("|---|---|---|")
for r in sorted(C,key=lambda x:x["key"]):
    why=(r.get("err") or f"HTTP {r['status']}")
    why=re.sub(r"HTTP(S)?ConnectionPool\(host='([^']+)'.*", r"连接失败 \2", why)
    why=re.sub(r"HTTPS?ConnectionPool\(host='([^']+)'.*", r"连接失败 \1", why)
    lines.append(f"| {r['key']} | {r['base'][:44]} | {why[:56]} |")
open("docs/cimoc-access.md","w",encoding="utf-8").write("\n".join(lines)+"\n")
print("A 类域名:", len(groups), " B:", len(B), " C:", len(C))
print("\nA 类清单：")
for h,rs in sorted(groups.items()):
    r=rs[0]
    print(f"  {h:28s} {r['title'][:26]:28s} {'/'.join(x['key'] for x in rs)[:40]}")
