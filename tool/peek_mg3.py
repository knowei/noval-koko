# -*- coding: utf-8 -*-
"""抓搜索结果条目的 HTML 片段。"""
import io
import re

h = io.open('tool/mg_search.html', encoding='utf-8').read()
for anchor in ['/novel/6bqYtWlkoay', '分类标签关联推荐']:
    i = h.find(anchor)
    print('===', anchor, 'at', i)
    if i > 0:
        print(h[max(0, i - 900):i + 900])
    print()
