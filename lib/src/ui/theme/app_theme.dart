import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

/// 界面字体：显式指定系统里的中文无衬线字体。
///
/// Flutter 在 Windows 上默认用 Segoe UI，这个字体没有中文字形，中文会回退
/// 到宋体一类衬线字体，小字号看起来发虚、笔画粗细不齐 —— 这就是「字体怪怪的」
/// 的来源。Android 上默认 Roboto 同理，回退结果随 ROM 而异。
/// 这里按平台点名一个正经的黑体，再给一串 fallback 兜底。
String get kUiFontFamily {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return 'Microsoft YaHei UI';
  }
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return 'PingFang SC';
  }
  return 'Noto Sans CJK SC';
}

/// 找不到上面的首选字体时依次尝试。
const List<String> kUiFontFallback = <String>[
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'PingFang SC',
  'Hiragino Sans GB',
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'Source Han Sans SC',
  'Segoe UI',
  'Roboto',
];

/// 间距与圆角：页面里不写死数字，统一从这里取。
class AppSpace {
  const AppSpace._();

  static const double page = 20;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;

  static BorderRadius get rSm => BorderRadius.circular(sm);
  static BorderRadius get rMd => BorderRadius.circular(md);
  static BorderRadius get rLg => BorderRadius.circular(lg);
  static BorderRadius get rPill => BorderRadius.circular(pill);
}

/// 一套配色。挂在 ThemeData 的 extensions 上，用 `context.palette` 取。
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.primaryDeep,
    required this.ink,
    required this.inkMid,
    required this.inkFaint,
    required this.line,
    required this.ok,
    required this.bad,
    required this.idle,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color primaryDeep;
  final Color ink;
  final Color inkMid;
  final Color inkFaint;
  final Color line;
  final Color ok;
  final Color bad;
  final Color idle;

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? primary,
    Color? primaryDeep,
    Color? ink,
    Color? inkMid,
    Color? inkFaint,
    Color? line,
    Color? ok,
    Color? bad,
    Color? idle,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      primary: primary ?? this.primary,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      ink: ink ?? this.ink,
      inkMid: inkMid ?? this.inkMid,
      inkFaint: inkFaint ?? this.inkFaint,
      line: line ?? this.line,
      ok: ok ?? this.ok,
      bad: bad ?? this.bad,
      idle: idle ?? this.idle,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDeep: Color.lerp(primaryDeep, other.primaryDeep, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMid: Color.lerp(inkMid, other.inkMid, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      line: Color.lerp(line, other.line, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      bad: Color.lerp(bad, other.bad, t)!,
      idle: Color.lerp(idle, other.idle, t)!,
    );
  }
}

/// 一个可选主题。以后加主题只要往 [kAppThemes] 里加一条。
@immutable
class AppTheme {
  const AppTheme({
    required this.id,
    required this.label,
    required this.primaryDark,
    required this.light,
  });

  final String id;
  final String label;

  /// 深色模式下的主色（阅读器/漫画用）。
  final Color primaryDark;
  final AppPalette light;

  /// 深色底（阅读器、漫画阅读器）。
  AppPalette get dark => AppPalette(
        bg: const Color(0xFF0F1613),
        surface: const Color(0xFF151E1A),
        surfaceAlt: const Color(0xFF1C2723),
        primary: primaryDark,
        primaryDeep: primaryDark,
        ink: const Color(0xFFEDEFE9),
        inkMid: const Color(0xFF9AA396),
        inkFaint: const Color(0xFF6C766C),
        line: const Color(0x14FFFFFF),
        ok: const Color(0xFF62A87E),
        bad: const Color(0xFFD0706A),
        idle: const Color(0xFF6C766C),
      );
}

/// 默认主题：墨町（米白纸 + 墨绿）。
const AppTheme kMotimg = AppTheme(
  id: 'moting',
  label: '墨町',
  primaryDark: Color(0xFF6E8F79),
  light: AppPalette(
    bg: Color(0xFFF7F9F3),
    surface: Color(0xFFFCFDF8),
    surfaceAlt: Color(0xFFEFF3EA),
    primary: Color(0xFF5C7A68),
    primaryDeep: Color(0xFF4B7358),
    ink: Color(0xFF2A3327),
    inkMid: Color(0xFF6E7A6C),
    inkFaint: Color(0xFF9AA396),
    line: Color(0x0F000000),
    ok: Color(0xFF4E9A6B),
    bad: Color(0xFFC1564E),
    idle: Color(0xFF9AA396),
  ),
);

/// 青瓷：偏冷一点的墨绿。
const AppTheme kCeladon = AppTheme(
  id: 'celadon',
  label: '青瓷',
  primaryDark: Color(0xFF6D9C90),
  light: AppPalette(
    bg: Color(0xFFF5F8F6),
    surface: Color(0xFFFCFEFC),
    surfaceAlt: Color(0xFFEAF1EE),
    primary: Color(0xFF4F7F76),
    primaryDeep: Color(0xFF3F6A62),
    ink: Color(0xFF22302C),
    inkMid: Color(0xFF6B7A76),
    inkFaint: Color(0xFF98A5A1),
    line: Color(0x0F000000),
    ok: Color(0xFF4E9A8B),
    bad: Color(0xFFBF5B52),
    idle: Color(0xFF98A5A1),
  ),
);

/// 暖沙：偏暖的卡其，夜里看着不刺眼。
const AppTheme kSand = AppTheme(
  id: 'sand',
  label: '暖沙',
  primaryDark: Color(0xFFA08A6A),
  light: AppPalette(
    bg: Color(0xFFF9F6EF),
    surface: Color(0xFFFDFBF5),
    surfaceAlt: Color(0xFFF1EBDF),
    primary: Color(0xFF8A7355),
    primaryDeep: Color(0xFF6F5C43),
    ink: Color(0xFF322C22),
    inkMid: Color(0xFF7C7365),
    inkFaint: Color(0xFFA79E8F),
    line: Color(0x0F000000),
    ok: Color(0xFF7C9A5E),
    bad: Color(0xFFC26450),
    idle: Color(0xFFA79E8F),
  ),
);

const List<AppTheme> kAppThemes = <AppTheme>[kMotimg, kCeladon, kSand];

AppTheme themeById(String id) {
  for (final AppTheme t in kAppThemes) {
    if (t.id == id) return t;
  }
  return kMotimg;
}

/// 用一套配色生成 ThemeData（颜色之外的东西也一并定好，页面里就不用关心了）。
ThemeData buildAppTheme(AppTheme theme, Brightness brightness) {
  final AppPalette p = brightness == Brightness.dark ? theme.dark : theme.light;
  final ColorScheme base =
      ColorScheme.fromSeed(seedColor: theme.primaryDark, brightness: brightness);
  final ColorScheme scheme = base.copyWith(
    primary: p.primary,
    onPrimary: brightness == Brightness.dark ? p.bg : Colors.white,
    primaryContainer: p.surfaceAlt,
    onPrimaryContainer: p.primaryDeep,
    secondary: p.primaryDeep,
    onSecondary: brightness == Brightness.dark ? p.bg : Colors.white,
    surface: p.bg,
    onSurface: p.ink,
    surfaceContainerHighest: p.surfaceAlt,
    surfaceContainerHigh: p.surface,
    onSurfaceVariant: p.inkMid,
    outline: p.inkFaint,
    outlineVariant: p.line,
    error: p.bad,
  );

  TextStyle t(double size, FontWeight weight,
          {double height = 1.4, Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? p.ink,
        letterSpacing: 0,
      );

  final TextTheme text = TextTheme(
    displayLarge: t(30, FontWeight.w700, height: 1.2),
    displayMedium: t(26, FontWeight.w700, height: 1.25),
    headlineSmall: t(20, FontWeight.w700, height: 1.3),
    titleLarge: t(20, FontWeight.w700, height: 1.3),
    titleMedium: t(15, FontWeight.w700),
    titleSmall: t(13, FontWeight.w700),
    bodyLarge: t(16, FontWeight.w400, height: 1.7),
    bodyMedium: t(15, FontWeight.w400, height: 1.6),
    bodySmall: t(12, FontWeight.w400, color: p.inkMid),
    labelLarge: t(14, FontWeight.w700),
    labelMedium: t(12, FontWeight.w400),
    labelSmall: t(11, FontWeight.w400),
  );

  // 所有文字统一走界面字体（含 CJK fallback）。
  final TextTheme uiText = text.apply(
    fontFamily: kUiFontFamily,
    fontFamilyFallback: kUiFontFallback,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kUiFontFamily,
    fontFamilyFallback: kUiFontFallback,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.line,
    textTheme: uiText,
    splashFactory: InkSparkle.splashFactory,
    extensions: <ThemeExtension<dynamic>>[p],
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: uiText.headlineSmall,
      iconTheme: IconThemeData(color: p.ink, size: 22),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(
          color: p.bg, fontSize: 13, fontFamily: kUiFontFamily),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rPill),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(0, 46),
        side: BorderSide(color: p.line),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rPill),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceAlt,
      hintStyle: TextStyle(color: p.inkFaint, fontSize: 15),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: AppRadius.rLg,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.rLg,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.rLg,
        borderSide: BorderSide(color: p.primary.withValues(alpha: 0.4)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
          s.contains(WidgetState.selected) ? Colors.white : p.surface),
      trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
          s.contains(WidgetState.selected) ? p.primary : p.surfaceAlt),
      trackOutlineColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
          s.contains(WidgetState.selected) ? Colors.transparent : p.line),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.inkMid,
      textColor: p.ink,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.inkFaint,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
      titleTextStyle: text.titleMedium,
      contentTextStyle: text.bodyMedium,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: const CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

extension AppPaletteContext on BuildContext {
  /// 当前配色。
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? kMotimg.light;

  TextTheme get text => Theme.of(this).textTheme;
}
