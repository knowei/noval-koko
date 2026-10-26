import re
html = open("tool/ln_probe/lib_search.html", encoding="utf-8", errors="replace").read()
print("search-result-list count:", html.count('class="search-result-list'))
print("se-result-infos count:", html.count("se-result-infos"))
i = html.find('class="search-result-list')
print(html[i-100:i+1800])
