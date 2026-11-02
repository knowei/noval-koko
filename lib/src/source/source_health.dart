/// 书源体检的分级结果。
///
/// 以前这里只有「可用 / 失效」两态，判定标准是「搜索请求没抛异常」，
/// 于是经常出现「搜出来有结果，点进去正文是空的」这种假阳性——
/// 界面上写着可用，实际看不了。
///
/// 现在按链路分级：网络 → 搜索 → 详情 → 目录 → 正文/图片。
/// 每一级都带时间戳和一句中文原因，界面只说它真的验到了哪一步。
enum SourceStage {
  /// 搜索请求直接失败（DNS / 超时 / 连接被重置 / HTTP 错误）
  networkFail,

  /// 请求通了，但一条结果都没有（站点改版、反爬、关键词不适用）
  emptyResult,

  /// 只验证到搜索有结果，正文没验（批量轻体检停在这一级）
  searchOnly,

  /// 详情页取不到书名
  detailFail,

  /// 目录一条都取不到
  tocFail,

  /// 章节能打开，但正文为空、也没有图片
  contentFail,

  /// 搜索 → 详情 → 目录 → 正文/图片 全链路通过
  readable,
}

class SourceHealth {
  const SourceHealth({
    required this.stage,
    required this.at,
    this.hits = 0,
    this.chapters = 0,
    this.textLength = 0,
    this.images = 0,
    this.note = '',
  });

  final SourceStage stage;
  final DateTime at;

  /// 搜索命中条数
  final int hits;

  /// 目录章节数（深检才有）
  final int chapters;

  /// 抽样章节的正文字数（深检才有）
  final int textLength;

  /// 抽样章节的图片张数（深检才有）
  final int images;

  /// 一句话原因，界面直接展示
  final String note;

  bool get readable => stage == SourceStage.readable;

  bool get searchOnly => stage == SourceStage.searchOnly;

  /// 真的坏了（区别于「还没测」和「只测了搜索」）
  bool get failed =>
      stage == SourceStage.networkFail ||
      stage == SourceStage.emptyResult ||
      stage == SourceStage.detailFail ||
      stage == SourceStage.tocFail ||
      stage == SourceStage.contentFail;

  String get label => switch (stage) {
        SourceStage.networkFail => '网络失败',
        SourceStage.emptyResult => '搜索无结果',
        SourceStage.searchOnly => '仅搜索通过',
        SourceStage.detailFail => '详情失败',
        SourceStage.tocFail => '目录失败',
        SourceStage.contentFail => '正文失败',
        SourceStage.readable => '可读',
      };

  /// 深检的时间 + 验到了什么，做成副标题
  String get detail {
    final String t = shortTime;
    if (!readable) return note.isEmpty ? t : '$note · $t';
    final String sample = images > 0 ? '$images 张图' : '$textLength 字';
    return '搜索 $hits 条 · 目录 $chapters 章 · 抽样正文 $sample · $t';
  }

  String get shortTime {
    String two(int v) => v < 10 ? '0$v' : '$v';
    return '${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
  }
}
