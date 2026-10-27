import sys
sys.stdout.reconfigure(encoding="utf-8")
p="lib/src/ui/reader/text_reader.dart"
t=open(p,encoding="utf-8").read()
old="""  @override
  void dispose() {
    _pageController.dispose();
    _scroll.dispose();
    super.dispose();
  }
"""
new="""  AppState? _appState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.read<AppState>();
  }

  @override
  void dispose() {
    // 退出阅读器时兜底存一次：滚动模式只滚了一点点、或刚进来就退出的情况
    // 之前会丢进度，回到书架再进就回到旧章节。
    final double offset = _appState == null
        ? 0
        : (_appState!.prefs.scrollMode
            ? _scrollFrac
            : (_pages.length <= 1 ? 0 : _page / (_pages.length - 1)));
    _appState?.saveProgress(widget.book, _index, offset: offset);
    _pageController.dispose();
    _scroll.dispose();
    super.dispose();
  }
"""
assert t.count(old)==1
open(p,"w",encoding="utf-8",newline="").write(t.replace(old,new))
print("ok")
