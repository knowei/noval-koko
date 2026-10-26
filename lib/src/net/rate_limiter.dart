import 'dart:async';

/// 按域名（host）限速：限制「并发数」和「两次请求之间的最小间隔」。
///
/// 目标站点通常不欢迎几十个请求同时打过去；阅读器的搜索/目录/正文/图片都会走这里，
/// 默认值取「同域最多 3 并发、间隔 200ms」，对单个站点足够礼貌也不至于太慢。
///
/// 书源里可以覆盖：[BookSource.concurrentRate] 的 Legado 写法是 `"间隔毫秒/并发数"`，
/// 例如 `"1000/1"` 表示 1 秒一次、只允许 1 个并发。
class RateLimiter {
  RateLimiter({
    this.defaultInterval = const Duration(milliseconds: 200),
    this.defaultConcurrency = 3,
  });

  final Duration defaultInterval;
  final int defaultConcurrency;

  final Map<String, _HostState> _hosts = <String, _HostState>{};

  _HostState _state(String host) => _hosts.putIfAbsent(
        host,
        () => _HostState(defaultInterval, defaultConcurrency),
      );

  /// 为某个域名单独设置限速（例如按书源的 concurrentRate）。
  void configure(
    String host, {
    Duration? interval,
    int? concurrency,
  }) {
    if (host.isEmpty) return;
    final _HostState st = _state(host.toLowerCase());
    if (interval != null) st.interval = interval;
    if (concurrency != null && concurrency > 0) st.concurrency = concurrency;
  }

  /// 解析 Legado 的 `concurrentRate`：`"1000/1"` → (1s, 1)。
  /// 返回 null 表示没写或写错，保持默认。
  static ({Duration interval, int concurrency})? parseRate(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return null;
    final List<String> parts = text.split('/');
    final int? ms = int.tryParse(parts.first.trim());
    if (ms == null || ms < 0) return null;
    int concurrency = 1;
    if (parts.length > 1) {
      final int? c = int.tryParse(parts[1].trim());
      if (c != null && c > 0) concurrency = c;
    }
    return (interval: Duration(milliseconds: ms), concurrency: concurrency);
  }

  /// 在限速约束下执行 [task]。
  Future<T> run<T>(String host, Future<T> Function() task) async {
    final String key = host.toLowerCase();
    if (key.isEmpty) return task();
    final _HostState st = _state(key);
    await _acquire(st);
    try {
      return await task();
    } finally {
      _release(st);
    }
  }

  Future<void> _acquire(_HostState st) async {
    while (st.active >= st.concurrency) {
      final Completer<void> waiter = Completer<void>();
      st.waiters.add(waiter);
      await waiter.future;
    }
    st.active++;
    final Duration wait = st.nextAt.difference(DateTime.now());
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }
    st.nextAt = DateTime.now().add(st.interval);
  }

  void _release(_HostState st) {
    if (st.active > 0) st.active--;
    if (st.waiters.isNotEmpty) {
      st.waiters.removeAt(0).complete();
    }
  }
}

class _HostState {
  _HostState(this.interval, this.concurrency);

  int active = 0;
  Duration interval;
  int concurrency;
  DateTime nextAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<Completer<void>> waiters = <Completer<void>>[];
}
