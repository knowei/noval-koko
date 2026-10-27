import 'package:flutter/material.dart';

/// 阅读器字体档位。正文默认给「宋体」，跟网页正文的观感更接近；
/// 系统默认（黑体）留着给喜欢无衬线的人。
class ReaderFont {
  const ReaderFont(this.id, this.label, this.family, this.fallback);

  final String id;
  final String label;
  final String? family;
  final List<String> fallback;

  static const ReaderFont system = ReaderFont('system', '系统', null, <String>[]);
  static const ReaderFont song = ReaderFont('song', '宋体', 'Songti SC', <String>[
    'SimSun',
    'NSimSun',
    'Noto Serif CJK SC',
    'Source Han Serif SC',
    'Noto Serif SC',
    'serif',
  ]);
  static const ReaderFont kai = ReaderFont('kai', '楷体', 'Kaiti SC', <String>[
    'KaiTi',
    'STKaiti',
    'Kaiti SC',
    'AR PL UKai CN',
    'serif',
  ]);
  static const ReaderFont hei = ReaderFont('hei', '黑体', 'PingFang SC', <String>[
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'sans-serif',
  ]);

  static const List<ReaderFont> all = <ReaderFont>[song, hei, kai, system];

  static ReaderFont byId(String? id) {
    for (final ReaderFont f in all) {
      if (f.id == id) return f;
    }
    return song;
  }

  /// 正文用的 TextStyle 片段。
  TextStyle apply({
    required double fontSize,
    required double lineHeight,
    Color? color,
  }) {
    final TextStyle base = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      color: color,
      letterSpacing: 0.3,
      // 让中英文混排的基线更稳，长段阅读不跳行
      leadingDistribution: TextLeadingDistribution.even,
    );
    if (family == null) return base;
    return base.copyWith(
      fontFamily: family,
      fontFamilyFallback: fallback,
    );
  }
}
