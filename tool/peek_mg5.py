# -*- coding: utf-8 -*-
"""详情页正文标记片段。"""
import io
import re

h = io.open('tool/mg_novel.html', encoding='utf-8').read()
i = h.find('class="book-name"')
print('idx', i)
print(h[max(0, i - 300):i + 2000])
