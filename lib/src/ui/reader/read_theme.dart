import 'package:flutter/material.dart';

export '../../core/html_text.dart';

/// 阅读器配色。
class ReadPalette {
  const ReadPalette(this.name, this.background, this.text, this.muted);

  final String name;
  final Color background;
  final Color text;
  final Color muted;

  static const List<ReadPalette> all = <ReadPalette>[
    ReadPalette('纸黄', Color(0xFFF5EFDF), Color(0xFF3A3226), Color(0xFF8C8272)),
    ReadPalette('月白', Color(0xFFFDFDFB), Color(0xFF222222), Color(0xFF8A8A8A)),
    ReadPalette('夜幕', Color(0xFF101014), Color(0xFFB6B6BC), Color(0xFF63636B)),
    ReadPalette('豆绿', Color(0xFFD6E8D2), Color(0xFF26311F), Color(0xFF6C7A63)),
  ];
}
