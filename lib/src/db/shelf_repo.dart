import 'package:sqflite/sqflite.dart';

import '../model/book_info.dart';
import '../model/shelf_book.dart';
import 'database.dart';

/// 书架、目录缓存、阅读进度、设置的读写。
class ShelfRepo {
  ShelfRepo([AppDatabase? database])
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<List<ShelfBook>> all() async {
    final List<Map<String, Object?>> rows =
        await _db.query('bookshelf', orderBy: 'last_read_time DESC');
    return rows.map(ShelfBook.fromMap).toList();
  }

  Future<ShelfBook?> find(String bookUrl) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'bookshelf',
      where: 'book_url = ?',
      whereArgs: <Object?>[bookUrl],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ShelfBook.fromMap(rows.first);
  }

  Future<void> upsert(ShelfBook book) async {
    await _db.insert(
      'bookshelf',
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> remove(String bookUrl) async {
    await _db.delete('bookshelf',
        where: 'book_url = ?', whereArgs: <Object?>[bookUrl]);
    await _db.delete('chapter',
        where: 'book_url = ?', whereArgs: <Object?>[bookUrl]);
  }

  Future<void> saveChapters(
      String bookUrl, List<BookChapter> chapters) async {
    final Batch batch = _db.batch();
    batch.delete('chapter',
        where: 'book_url = ?', whereArgs: <Object?>[bookUrl]);
    for (final BookChapter c in chapters) {
      batch.insert(
        'chapter',
        <String, Object?>{
          'book_url': bookUrl,
          'idx': c.index,
          'title': c.title,
          'url': c.url,
          'is_vip': c.isVip ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    batch.update(
      'bookshelf',
      <String, Object?>{
        'total_chapters': chapters.length,
        'latest_chapter': chapters.isEmpty ? '' : chapters.last.title,
        'toc_url': chapters.isEmpty ? '' : '',
      },
      where: 'book_url = ?',
      whereArgs: <Object?>[bookUrl],
    );
    await batch.commit(noResult: true);
  }

  Future<List<BookChapter>> chapters(String bookUrl) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'chapter',
      where: 'book_url = ?',
      whereArgs: <Object?>[bookUrl],
      orderBy: 'idx ASC',
    );
    return rows
        .map((Map<String, Object?> m) => BookChapter(
              title: (m['title'] as String?) ?? '',
              url: (m['url'] as String?) ?? '',
              index: (m['idx'] as int?) ?? 0,
              isVip: ((m['is_vip'] as int?) ?? 0) == 1,
            ))
        .toList();
  }

  Future<void> saveProgress({
    required String bookUrl,
    required int index,
    double offset = 0,
  }) async {
    await _db.update(
      'bookshelf',
      <String, Object?>{
        'last_read_index': index,
        'last_read_offset': offset,
        'last_read_time': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'book_url = ?',
      whereArgs: <Object?>[bookUrl],
    );
  }

  // ------------------------------------------------------------- settings

  Future<String?> getSetting(String key) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'app_setting',
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await _db.insert(
      'app_setting',
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
