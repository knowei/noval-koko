import glob, json, io, os, re

KW = ['轻小说', '輕小說', '文库', '文庫', 'linovel', 'bilinovel', 'wenku8', 'esj', 'masiro',
      'lightnovel', 'light-novel', 'lnovel', '轻之', '真白萌', 'SF轻', '次元']

def walk(obj, out):
    if isinstance(obj, dict):
        if 'bookSourceUrl' in obj and 'bookSourceName' in obj:
            out.append(obj)
        else:
            for v in obj.values():
                walk(v, out)
    elif isinstance(obj, list):
        for v in obj:
            walk(v, out)

seen = {}
files = glob.glob('tool/scan_raw/*.json')
for f in files:
    try:
        data = json.load(io.open(f, encoding='utf-8-sig'))
    except Exception:
        continue
    items = []
    walk(data, items)
    for s in items:
        name = str(s.get('bookSourceName') or '')
        url = str(s.get('bookSourceUrl') or '')
        blob = (name + ' ' + url + ' ' + str(s.get('searchUrl') or '')).lower()
        if any(k.lower() in blob for k in KW):
            key = url.rstrip('/')
            if key not in seen:
                seen[key] = {
                    'name': name, 'url': url,
                    'type': s.get('bookSourceType'),
                    'search': str(s.get('searchUrl') or '')[:160],
                    'file': os.path.basename(f),
                }

rows = sorted(seen.values(), key=lambda r: r['name'])
with io.open('tool/ln_candidates.txt', 'w', encoding='utf-8') as fh:
    fh.write('total=%d\n' % len(rows))
    for r in rows:
        fh.write('%s\t%s\ttype=%s\t%s\t%s\n' % (r['name'], r['url'], r['type'], r['search'], r['file']))
print('total', len(rows))
