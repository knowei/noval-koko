import 'package:flutter/material.dart';

/// 全局动效节奏：快（按下反馈）/ 中（入场、转场）/ 慢（大块元素）。
const Duration kMotionFast = Duration(milliseconds: 160);
const Duration kMotionMid = Duration(milliseconds: 280);
const Duration kMotionSlow = Duration(milliseconds: 420);

/// 默认缓动：起步快、收尾稳，适合「墨町」这种安静的纸感界面。
const Curve kMotionCurve = Curves.easeOutCubic;

/// 错峰间隔：列表第 n 项的入场延迟 = index * kStagger。
const Duration kStagger = Duration(milliseconds: 26);

/// 入场：淡入 + 轻微上浮。
///
/// 用单个 [AnimationController] + [Interval] 实现「延迟」，不排 Timer，
/// 这样 widget 测试里不会留下未完成的定时器。
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.duration = kMotionMid,
    this.rise = 10,
  });

  final Widget child;

  /// 列表序号，用于错峰（最多叠加到第 12 项）。
  final int index;

  /// 额外延迟。
  final Duration delay;
  final Duration duration;

  /// 上浮距离（px）。
  final double rise;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final Duration _delay = widget.delay +
      Duration(milliseconds: kStagger.inMilliseconds * widget.index.clamp(0, 12));
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    final int totalMs = _delay.inMilliseconds + widget.duration.inMilliseconds;
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs == 0 ? 1 : totalMs),
    );
    final double start =
        totalMs == 0 ? 0 : _delay.inMilliseconds / totalMs.toDouble();
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(start, 1, curve: kMotionCurve),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (BuildContext context, Widget? child) {
        final double v = _t.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * widget.rise),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 按下时轻微缩小的点击包皮，让可点的卡片/封面有触感。
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.972,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final HitTestBehavior behavior;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: kMotionFast,
        curve: kMotionCurve,
        child: widget.child,
      ),
    );
  }
}

/// 统一转场：淡入 + 3% 上浮。比 Material 默认的缩放推入更安静。
Route<T> fadeSlideRoute<T>(Widget page, {Duration? duration}) {
  final Duration d = duration ?? kMotionMid;
  return PageRouteBuilder<T>(
    transitionDuration: d,
    reverseTransitionDuration: kMotionFast,
    pageBuilder: (BuildContext context, Animation<double> a,
            Animation<double> s) =>
        page,
    transitionsBuilder: (BuildContext context, Animation<double> a,
        Animation<double> s, Widget child) {
      final CurvedAnimation c = CurvedAnimation(
        parent: a,
        curve: kMotionCurve,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: c,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.028),
            end: Offset.zero,
          ).animate(c),
          child: child,
        ),
      );
    },
  );
}

/// 内容切换：淡入 + 一点缩放，避免「啪」地换掉。
class FadeSwitch extends StatelessWidget {
  const FadeSwitch({
    super.key,
    required this.child,
    this.duration = kMotionMid,
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: kMotionCurve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget c, Animation<double> a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(a),
          child: c,
        ),
      ),
      child: child,
    );
  }
}
