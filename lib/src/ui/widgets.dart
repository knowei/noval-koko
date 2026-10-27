import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/text_util.dart';
import 'theme/app_theme.dart';

/// 封面共享元素 tag：同一本书在列表与详情之间要一致。
String coverHeroTag(String sourceUrl, String bookUrl) =>
    'cover:$sourceUrl|$bookUrl';

/// 书籍封面：3:4、圆角、无图兜底。
class BookCover extends StatefulWidget {
  const BookCover({
    super.key,
    required this.url,
    required this.name,
    this.width = 92,
    this.height,
    this.radius = AppRadius.md,
    this.badge,
  });

  final String url;
  final String name;
  final double width;

  /// 不传则按 3:4 算。
  final double? height;
  final double radius;

  /// 右上角角标（进度之类）。
  final String? badge;

  @override
  State<BookCover> createState() => _BookCoverState();
}

class _BookCoverState extends State<BookCover> {
  /// 图床镜像下标：一张图失败就换镜像域名重试。
  int _mirror = 0;

  @override
  void didUpdateWidget(covariant BookCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _mirror = 0;
  }

  double get _height => widget.height ?? widget.width * 4 / 3;

  void _tryNextMirror(List<String> variants) {
    if (_mirror + 1 >= variants.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _mirror += 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double width = widget.width;
    final String url = widget.url;
    final String name = widget.name;
    final double radius = widget.radius;
    final String? badge = widget.badge;
    final AppPalette p = context.palette;

    final Widget fallback = Container(
      width: width,
      height: _height,
      alignment: Alignment.center,
      color: p.surfaceAlt,
      child: Text(
        name.isEmpty ? '书' : name.characters.first,
        style: TextStyle(
          fontSize: width * 0.36,
          color: p.inkFaint,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final List<String> variants =
        url.trim().isEmpty ? const <String>[] : TextUtil.imageUrlVariants(url);
    final String imageUrl = variants.isEmpty
        ? url
        : variants[_mirror.clamp(0, variants.length - 1)];

    final Widget image = variants.isEmpty
        ? fallback
        : CachedNetworkImage(
            imageUrl: imageUrl,
            httpHeaders: TextUtil.imageHeaders(imageUrl),
            width: width,
            height: _height,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 160),
            placeholder: (BuildContext c, String u) => Container(
              width: width,
              height: _height,
              color: p.surfaceAlt,
            ),
            errorWidget: (BuildContext c, String u, Object e) {
              _tryNextMirror(variants);
              return fallback;
            },
          );


    return SizedBox(
      width: width,
      height: _height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            image,
            if (badge != null && badge.isNotEmpty)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.1,
                      color: Colors.white,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 页面大标题（书架 / 搜索 / 书源）。
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.page, AppSpace.lg, AppSpace.page, AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 6)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: context.text.displayLarge),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          for (final Widget a in actions) ...<Widget>[a, const SizedBox(width: 4)],
        ],
      ),
    );
  }
}

/// 区块标题 + 右侧「全部 ›」之类。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.page, AppSpace.lg, AppSpace.page, AppSpace.sm),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Text(title, style: context.text.titleMedium),
            const SizedBox(width: 6),
            if (trailing != null)
              Text(trailing!, style: context.text.bodySmall)
            else
              const Spacer(),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 16, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// 书源名小标签：搜索结果的每一行后面挂它。
class SourceTag extends StatelessWidget {
  const SourceTag(this.name, {super.key, this.type});

  final String name;

  /// 1 = 漫画，用于右侧小图标。
  final int? type;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: 0.10),
        borderRadius: AppRadius.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (type == 1) ...<Widget>[
            Icon(Icons.image_outlined, size: 11, color: p.primary),
            const SizedBox(width: 3),
          ],
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: p.primary,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// 胶囊筛选片。
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? p.primary : Colors.transparent,
          borderRadius: AppRadius.rPill,
          border: Border.all(color: selected ? Colors.transparent : p.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : p.inkMid,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

/// 卡片容器：细描边 + 极轻阴影。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;

    final Widget box = Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: p.line),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF141E14).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
  }
}

/// 空状态提示。
class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: p.inkFaint),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              title,
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpace.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
