import json,sys,urllib.request
sys.stdout.reconfigure(encoding="utf-8")
UA={"User-Agent":"Mozilla/5.0","Accept":"application/vnd.github+json"}
def get(u):
    op=urllib.request.build_opener(urllib.request.ProxyHandler({"http":"http://127.0.0.1:7897","https":"http://127.0.0.1:7897"}))
    return op.open(urllib.request.Request(u,headers=UA),timeout=25).read().decode("utf-8","ignore")
try:
    d=json.loads(get("https://api.github.com/repos/knowei/noval-koko/actions/runs?per_page=6"))
    for r in d.get("workflow_runs",[]):
        print(r["id"], r["head_branch"], r["event"], r["status"], r["conclusion"], r["head_sha"][:7], r["created_at"])
except Exception as e:
    print("ERR",e)
