import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../net/http_service.dart';

/// 走自家 Dio 通道的图片 provider。
///
/// 存在的理由：`Image.network`（即 `NetworkImage`）内部是
/// `request.headers.add('User-Agent', ...)`，而 dart:io 的 `HttpClient` 自带一个
/// 默认 UA（`Dart/3.x (dart:io)`），`add` 会让请求带上**两个 UA 头** ——
/// Cloudflare 前面的图床（包子漫画的 `c-nd2-1.6wm.top` 等）会直接 403。
/// 实测：`set` → 200，`add` → 403（见 README「图片加载失败」小节）。
///
/// 这里用 [HttpService.fetchImage] 拿字节（Dio，set 语义 + 镜像轮换 + Referer
/// 回退），再交给 Flutter 解码；仍然吃 `ImageCache`，同一 URL 只下一次。
@immutable
class NetImageProvider extends ImageProvider<NetImageProvider> {
  const NetImageProvider(this.http, this.url, {this.referer});

  final HttpService http;
  final String url;
  final String? referer;

  @override
  Future<NetImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<NetImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    NetImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: key.url,
    );
  }

  Future<ui.Codec> _loadAsync(
    NetImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final Uint8List bytes = await http.fetchImage(key.url, referer: key.referer);
    if (bytes.isEmpty) {
      throw StateError('图片内容为空：${key.url}');
    }
    final ui.ImmutableBuffer buffer =
        await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is NetImageProvider &&
      other.url == url &&
      other.referer == referer;

  @override
  int get hashCode => Object.hash(url, referer);

  @override
  String toString() => 'NetImageProvider("$url")';
}
