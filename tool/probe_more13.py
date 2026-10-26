import re

b = open('tool/ln_probe/pg1342.html', encoding='utf-8', errors='replace').read()
print('len', len(b))
for pat in ('id="pg-', 'class="chapter', '<div class="body', 'pgtext', 'id="main"',
            'role="main"', 'itemprop="text"', 'class="fiction'):
    print(pat, b.count(pat))
i = b.find('CHAPTER I.')
print('CHAPTER I ctx:', b[max(0, i - 300):i + 200].replace('\n', ' ')[:400])
for m in re.finditer(r'<(div|section|article)[^>]*(id|class)="[^"]*(?:text|body|main|content)[^"]*"[^>]*>', b):
    print('WRAP', m.group(0)[:120])
