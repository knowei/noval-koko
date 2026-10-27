/// 把 GitHub Release 的 markdown 正文转成「人话」——给应用内更新弹窗用。
///
/// GitHub 自动生成的 notes 长这样：
/// ```
/// ## What's Changed
/// * fix: 详情页按钮 by @knowei in https://github.com/knowei/noval-koko/pull/12
/// * feat: 暗色模式 by @knowei in https://github.com/knowei/noval-koko/pull/13
///
/// **Full Changelog**: https://github.com/.../compare/v0.5.0...v0.6.0
/// ```
/// 直接丢进弹窗里全是标记符号和 compare 链接，很丑。这里做最小清洗：
/// 去掉 markdown 标记、把 `* ` 换成「· 」、砍掉 "Full Changelog" 和
/// "New Contributors" 之后的内容、去掉 `by @user in <链接>` 后缀。
class ReleaseNotes {
  const ReleaseNotes._();

  /// 清洗后的纯文本；没有可用内容时返回 [fallback]。
  static String plain(String markdown, {String fallback = '这个版本没有写更新说明。'}) {
    final List<String> raw = markdown.replaceAll('\r\n', '\n').split('\n');
    final List<String> out = <String>[];

    for (String line in raw) {
      final String t = line.trimRight();

      // 「New Contributors」之后都是自动生成的新人名单，对用户没价值。
      if (RegExp(r'^#+\s*new contributors', caseSensitive: false).hasMatch(t.trim())) {
        break;
      }
      // Full Changelog 那行整行丢掉。
      if (t.toLowerCase().contains('full changelog')) continue;
      // 纯分隔线。
      if (RegExp(r'^[-\s*_]{3,}$').hasMatch(t)) continue;

      String s = t.trim();

      if (s.isEmpty) {
        // 只保留一个空行，用来分段。
        if (out.isNotEmpty && out.last.isNotEmpty) out.add('');
        continue;
      }

      // 标题：保留文字，不加 #。
      s = s.replaceFirst(RegExp(r'^#{1,6}\s*'), '');

      // 列表项 → 「· 」。
      final bool wasBullet = RegExp(r'^[-*+]\s+').hasMatch(s);
      s = s.replaceFirst(RegExp(r'^[-*+]\s+'), '· ');

      // GitHub 自动 notes 是 PR 标题，常带 conventional commit 前缀，
      // 对用户来说只有噪音：`feat: 暗色模式` → `暗色模式`。
      if (wasBullet) {
        s = s.replaceFirst(
            RegExp(r'^·\s*(feat|fix|chore|docs|refactor|style|perf|test|build|ci)(\([^)]*\))?!?:\s*',
                caseSensitive: false),
            '· ');
      }

      // 去掉 `by @someone in https://...` 尾巴。
      s = s.replaceFirst(
          RegExp(r'\s+by\s+@[A-Za-z0-9\-_]+\s+in\s+https?://\S+$'), '');

      // 去掉纯链接尾巴（`… https://…`）。
      s = s.replaceFirst(RegExp(r'\s+https?://\S+$'), '');

      // markdown 链接 → 文字。
      s = s.replaceAllMapped(
          RegExp(r'\[([^\]]*)\]\(([^)]*)\)'), (Match m) => m.group(1) ?? '');
      // 粗体/斜体/行内代码。
      s = s.replaceAll('**', '').replaceAll('__', '').replaceAll('`', '');
      s = s.replaceAll(RegExp(r'(?<!\w)\*(?=\S)'), '').replaceAll(RegExp(r'\*(?!\w)'), '');

      s = s.trim();
      if (s.isEmpty) continue;
      out.add(s);
    }

    // 去掉末尾空行。
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    if (out.isEmpty) return fallback;
    return out.join('\n');
  }

  /// 清洗后按行返回（弹窗里想自己排版时用）。
  static List<String> lines(String markdown) =>
      plain(markdown).split('\n').map((String s) => s.trim()).toList();
}
