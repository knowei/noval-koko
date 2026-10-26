import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/update_service.dart';
import '../core/version.dart';
import 'motion.dart';
import 'theme/app_theme.dart';
import 'widgets.dart';

/// 「我的 → 关于」里的检查更新入口：查 GitHub Release、下载 APK、拉起系统安装。
class UpdateEntry extends StatefulWidget {
  const UpdateEntry({super.key});

  @override
  State<UpdateEntry> createState() => _UpdateEntryState();
}

enum _Phase { idle, checking, upToDate, available, downloading, error }

class _UpdateEntryState extends State<UpdateEntry> {
  final UpdateService _service = UpdateService();

  _Phase _phase = _Phase.idle;
  ReleaseInfo? _info;
  String _message = '';
  double _progress = 0;
  CancelToken? _cancel;

  bool get _busy => _phase == _Phase.checking || _phase == _Phase.downloading;

  String get _subtitle {
    switch (_phase) {
      case _Phase.idle:
        return '当前 v$kAppVersion';
      case _Phase.checking:
        return '正在检查…';
      case _Phase.upToDate:
        return '已是最新版本 v$kAppVersion';
      case _Phase.available:
        return '发现 ${_info?.tag ?? ''}，点此更新';
      case _Phase.downloading:
        return '下载中 ${(_progress * 100).toStringAsFixed(0)}%';
      case _Phase.error:
        return _message;
    }
  }

  Future<void> _check({bool silent = false}) async {
    if (_busy) return;
    setState(() {
      _phase = _Phase.checking;
      _message = '';
    });
    try {
      final ReleaseInfo? info = await _service.fetchLatest();
      if (!mounted) return;
      if (info == null) {
        setState(() {
          _phase = _Phase.error;
          _message = '没拿到 Release 信息';
        });
        return;
      }
      _info = info;
      final bool newer = _service.hasUpdate(info);
      setState(() {
        _phase = newer ? _Phase.available : _Phase.upToDate;
      });
      if (newer && !silent) await _showUpdateDialog(info);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _message = e.response?.statusCode == 404
            ? '仓库还没有 Release'
            : '检查失败：${e.type.name}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _message = '检查失败：$e';
      });
    }
  }

  Future<void> _showUpdateDialog(ReleaseInfo info) async {
    final AppPalette p = context.palette;
    final String size = info.asset == null
        ? '这个 Release 没有 APK'
        : '${(info.asset!.size / 1024 / 1024).toStringAsFixed(1)} MB';
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('发现新版本 ${info.version}', style: c.text.titleMedium),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('${info.asset?.name ?? '无 APK'} · $size',
                  style: c.text.bodySmall),
              if (info.body.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpace.md),
                Text(info.body.trim(),
                    style: c.text.bodySmall, maxLines: 12,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(Platform.isAndroid ? '下载并安装' : '打开下载页'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await _downloadAndInstall(info);
  }

  Future<void> _downloadAndInstall(ReleaseInfo info) async {
    if (!Platform.isAndroid) {
      final String r = await _service.install(info);
      if (!mounted) return;
      _toast(r);
      return;
    }
    if (info.asset == null) {
      _toast('这个 Release 没有 APK');
      return;
    }
    _cancel = CancelToken();
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
    });
    try {
      final File apk = await _service.download(
        info,
        cancelToken: _cancel,
        onProgress: (int received, int total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = received / total);
        },
      );
      if (!mounted) return;
      setState(() => _phase = _Phase.available);
      final String r = await _service.install(info, apk: apk);
      if (!mounted) return;
      _toast(r);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _message = e.type == DioExceptionType.cancel ? '已取消下载' : '下载失败：${e.type.name}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _message = '下载失败：$e';
      });
    } finally {
      _cancel = null;
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg, vertical: AppSpace.md),
      onTap: () {
        if (_busy) return;
        if (_phase == _Phase.available && _info != null) {
          _downloadAndInstall(_info!);
        } else {
          _check();
        }
      },
      child: Row(
        children: <Widget>[
          Icon(
            _phase == _Phase.available
                ? Icons.system_update_alt
                : Icons.autorenew,
            size: 19,
            color: _phase == _Phase.available ? p.primary : p.inkMid,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '检查更新',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: kMotionFast,
                  child: Text(
                    _subtitle,
                    key: ValueKey<String>(_subtitle),
                    style: context.text.bodySmall,
                  ),
                ),
                if (_phase == _Phase.downloading) ...<Widget>[
                  const SizedBox(height: AppSpace.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _progress == 0 ? null : _progress,
                      minHeight: 4,
                      backgroundColor: p.line,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          if (_busy)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
            )
          else
            Icon(
              _phase == _Phase.available
                  ? Icons.chevron_right
                  : Icons.refresh,
              size: 18,
              color: p.inkFaint,
            ),
        ],
      ),
    );
  }
}
