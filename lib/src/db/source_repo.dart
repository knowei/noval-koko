import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../model/book_source.dart';
import 'database.dart';

/// 书源的持久化与导入导出。
class SourceRepo {
  SourceRepo([AppDatabase? database])
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<List<BookSource>> all() async {
    final List<Map<String, Object?>> rows =
        await _db.query('book_source', orderBy: 'sort ASC, name ASC');
    final List<BookSource> out = <BookSource>[];
    for (final Map<String, Object?> row in rows) {
      try {
        final Object? decoded = jsonDecode((row['json'] as String?) ?? '{}');
        if (decoded is Map<String, dynamic>) {
          out.add(BookSource.fromJson(decoded));
        }
      } catch (_) {
        // 跳过损坏的记录
      }
    }
    return out;
  }

  Future<BookSource?> find(String url) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'book_source',
      where: 'url = ?',
      whereArgs: <Object?>[url],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode((rows.first['json'] as String?) ?? '');
      if (decoded is Map<String, dynamic>) return BookSource.fromJson(decoded);
    } catch (_) {}
    return null;
  }

  /// 保存一批书源，返回「新增/更新」的条数。
  Future<int> saveAll(List<BookSource> sources, {bool replaceAll = false}) async {
    if (replaceAll) {
      await _db.delete('book_source');
    }
    final Batch batch = _db.batch();
    int count = 0;
    for (final BookSource s in sources) {
      if (s.url.isEmpty) continue;
      batch.insert(
        'book_source',
        <String, Object?>{
          'url': s.url,
          'name': s.name,
          'type': s.type,
          'group_name': s.group,
          'enabled': s.enabled ? 1 : 0,
          'sort': s.weight,
          'json': jsonEncode(s.toJson()),
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      count++;
    }
    await batch.commit(noResult: true);
    return count;
  }

  Future<void> setEnabled(String url, bool enabled) async {
    await _db.update(
      'book_source',
      <String, Object?>{'enabled': enabled ? 1 : 0},
      where: 'url = ?',
      whereArgs: <Object?>[url],
    );
  }

  Future<void> remove(Iterable<String> urls) async {
    if (urls.isEmpty) return;
    final List<String> list = urls.toList();
    final String marks = List<String>.filled(list.length, '?').join(',');
    await _db.delete('book_source',
        where: 'url IN ($marks)', whereArgs: <Object?>[...list]);
  }

  /// 解析用户导入的文本：支持 JSON 数组、单个对象、每行一个 JSON。
  static List<BookSource> parseSources(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return <BookSource>[];

    final List<Map<String, dynamic>> rawList = <Map<String, dynamic>>[];

    void collect(Object? node) {
      if (node is List) {
        for (final Object? e in node) {
          collect(e);
        }
      } else if (node is Map) {
        // Legado 的分享 / 订阅格式会包一层：{"bookSources":[...]}
        final Object? nested = node['bookSources'] ?? node['sources'];
        if (nested is List && !node.containsKey('bookSourceUrl')) {
          collect(nested);
          return;
        }
        rawList.add(node.map((Object? k, Object? v) =>
            MapEntry<String, dynamic>(k.toString(), v)));
      }
    }

    try {
      collect(jsonDecode(trimmed));
    } catch (_) {
      for (final String line in trimmed.split('\n')) {
        final String l = line.trim();
        if (!l.startsWith('{')) continue;
        try {
          collect(jsonDecode(l));
        } catch (_) {}
      }
    }

    final List<BookSource> out = <BookSource>[];
    for (final Map<String, dynamic> raw in rawList) {
      // 兼容只给了书籍信息的 JSON，直接跳过
      if (!raw.containsKey('bookSourceUrl')) {
        if (raw.containsKey('bookSourceName')) {
          raw['bookSourceUrl'] = '';
        } else {
          continue;
        }
      }
      out.add(BookSource.fromJson(raw));
    }
    return out;
  }

  /// 导出为 JSON 数组文本。
  Future<String> exportAll({bool enabledOnly = false}) async {
    final List<BookSource> sources = await all();
    final List<Map<String, dynamic>> list = sources
        .where((BookSource s) => !enabledOnly || s.enabled)
        .map((BookSource s) => s.toJson())
        .toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }
}
