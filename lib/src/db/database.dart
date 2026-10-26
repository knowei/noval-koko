import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 本地 SQLite。桌面端用 ffi，移动端用系统 SQLite。
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Database get db {
    final Database? d = _db;
    if (d == null) {
      throw StateError('数据库尚未初始化，请先调用 AppDatabase.instance.init()');
    }
    return d;
  }

  bool get isReady => _db != null;

  /// [path] 只给测试用：传进来就用这个库文件，避免污染真实书架。
  Future<void> init({String? path}) async {
    if (_db != null) return;

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String? dbPath = path;
    if (dbPath == null) {
      final Directory dir = await getApplicationSupportDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      dbPath = p.join(dir.path, 'noval.db');
    }
    _db = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bookshelf(
        book_url TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        author TEXT NOT NULL DEFAULT '',
        cover TEXT NOT NULL DEFAULT '',
        intro TEXT NOT NULL DEFAULT '',
        kind TEXT NOT NULL DEFAULT '',
        source_url TEXT NOT NULL DEFAULT '',
        source_name TEXT NOT NULL DEFAULT '',
        type INTEGER NOT NULL DEFAULT 0,
        toc_url TEXT NOT NULL DEFAULT '',
        total_chapters INTEGER NOT NULL DEFAULT 0,
        latest_chapter TEXT NOT NULL DEFAULT '',
        last_read_index INTEGER NOT NULL DEFAULT 0,
        last_read_offset REAL NOT NULL DEFAULT 0,
        last_read_time INTEGER NOT NULL DEFAULT 0,
        created_time INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE chapter(
        book_url TEXT NOT NULL,
        idx INTEGER NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        url TEXT NOT NULL DEFAULT '',
        is_vip INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(book_url, idx)
      )
    ''');

    await db.execute('''
      CREATE TABLE book_source(
        url TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        type INTEGER NOT NULL DEFAULT 0,
        group_name TEXT NOT NULL DEFAULT '',
        enabled INTEGER NOT NULL DEFAULT 1,
        sort INTEGER NOT NULL DEFAULT 0,
        json TEXT NOT NULL,
        updated_time INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE app_setting(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_chapter_book ON chapter(book_url, idx)');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
