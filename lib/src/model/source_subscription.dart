/// 一条书源订阅：一个 URL，指过去能拿到一整包书源 JSON。
///
/// 为什么不把订阅写进书源表：订阅是本地的「收件箱」，删掉订阅不该连带
/// 删掉已经导入的源；反过来更新订阅也不该覆盖用户改过的启用状态——
/// 除了 enabled，其它字段跟着订阅走。
class SourceSubscription {
  const SourceSubscription({
    required this.url,
    this.name = '',
    this.count = 0,
    this.lastSync = 0,
  });

  final String url;

  /// 订阅名（拉成功后用里面第一个源的名字兜底，或者用域名）。
  final String name;

  /// 上次拉到多少个源。
  final int count;

  /// 上次同步时间（毫秒）。
  final int lastSync;

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    final String host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? url : host;
  }

  String get lastSyncText {
    if (lastSync <= 0) return '从未更新';
    final DateTime t = DateTime.fromMillisecondsSinceEpoch(lastSync);
    final Duration ago = DateTime.now().difference(t);
    if (ago.inMinutes < 1) return '刚刚更新';
    if (ago.inHours < 1) return '${ago.inMinutes} 分钟前更新';
    if (ago.inDays < 1) return '${ago.inHours} 小时前更新';
    return '${ago.inDays} 天前更新';
  }

  SourceSubscription copyWith({
    String? url,
    String? name,
    int? count,
    int? lastSync,
  }) =>
      SourceSubscription(
        url: url ?? this.url,
        name: name ?? this.name,
        count: count ?? this.count,
        lastSync: lastSync ?? this.lastSync,
      );

  factory SourceSubscription.fromJson(Map<String, dynamic> j) =>
      SourceSubscription(
        url: '${j['url'] ?? ''}'.trim(),
        name: '${j['name'] ?? ''}',
        count: j['count'] is int ? j['count'] as int : 0,
        lastSync: j['lastSync'] is int ? j['lastSync'] as int : 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        'name': name,
        'count': count,
        'lastSync': lastSync,
      };
}
