# -*- coding: utf-8 -*-
"""详情页：类名清单 + 「章节」相关片段。"""
import io
import re
from collections import Counter

h = io.open('tool/mg_novel.html', encoding='utf-8').read()
cls = Counter()
for m in re.finditer(r'class="([^"]+)"', h):
    for c in m.group(1).split():
        cls[c] += 1
print('--- 主要 class（去掉带 data-v 的样式类） ---')
for c, n in cls.most_common(60):
    print('  %-32s %d' % (c, n))

print('--- 含「章」的文本片段 ---')
for m in list(re.finditer('章', h))[:8]:
    seg = h[max(0, m.start() - 120):m.start() + 120].replace('\n', ' ')
    print('   ...', re.sub(r'<[^>]+>', '·', seg))
