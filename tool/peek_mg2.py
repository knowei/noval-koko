# -*- coding: utf-8 -*-
"""看 /search 页面的结果结构。"""
import io
import re

h = io.open('tool/mg_search.html', encoding='utf-8').read()
i = h.find('解忧')
print('--- 首次出现上下文 ---')
print(h[max(0, i - 1500):i + 1500])
