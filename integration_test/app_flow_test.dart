// App 级全链路测试：走真实代码路径（SQLite + Repo + AppState + SourceEngine + 网络），
// 验证「导入活源 → 搜索 → 入架 → 拉目录 → 读正文 / 漫画图片 → 存进度 → 重开仍在」。
// 跑法：flutter test integration_test/app_flow_test.dart -d windows
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/app_state.dart';
import 'package:noval/src/db/database.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/shelf_book.dart';

const String kKeyword = '剑来';
const String kDbPath = 'tool/app_flow_test.db';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final File f = File(kDbPath);
    if (f.existsSync()) f.deleteSync();
    // 用独立库文件，不碰真实书架
    await AppDatabase.instance.init(path: kDbPath);
  });

  tearDownAll(() async {
    await AppDatabase.instance.close();
    final File f = File(kDbPath);
    if (f.existsSync()) f.deleteSync();
  });

  test('导入活源 → 搜索 → 入架 → 目录 → 正文/图片 → 进度持久化', () async {
    final String liveJson = File('docs/live_sources.json').readAsStringSync();
    final AppState st = AppState();
    await st.bootstrap();
    expect(st.ready, isTrue);

    // 1) 导入书源（走 App 的导入路径，含 JSON 解析与入库）
    final int imported = await st.importText(liveJson);
    expect(imported, greaterThanOrEqualTo(3), reason: '三个活源都应导入成功');
    expect(st.searchableSources.length, greaterThanOrEqualTo(3));

    // 2) 搜索
    final List<SearchOutcome> outcomes = <SearchOutcome>[];
    await st.searchAll(kKeyword, onOutcome: outcomes.add);
    final List<SearchOutcome> hit =
        outcomes.where((SearchOutcome o) => o.ok && o.books.isNotEmpty).toList();
    expect(hit, isNotEmpty,
        reason: '至少一个源要搜到《$kKeyword》：'
            '${outcomes.map((SearchOutcome o) => '${o.sourceName}:'
                '${o.ok ? o.books.length : o.error}').join('; ')}');

    // 3) 小说链路：找一本「正文真能读」的书
    //    （有的书章节被站点标「未审核」或锁章，正文为空，所以要在候选里挑）
    ShelfBook? novel;
    BookInfo? novelInfo;
    List<BookChapter> chapters = <BookChapter>[];
    BookContent? content;
    int mid = 0;
    final StringBuffer tried = StringBuffer();
    for (final SearchOutcome o in hit) {
      if (novel != null) break;
      for (final dynamic nb in o.books.take(3)) {
        if ((nb.type as int?) == 2) continue;
        final BookInfo info;
        try {
          info = await st.engine.bookInfo(
            st.sourceOf(o.sourceUrl)!,
            nb.bookUrl as String,
            fallbackName: nb.name as String,
            fallbackAuthor: nb.author as String,
          );
        } catch (e) {
          tried.writeln('${o.sourceName}/${nb.name} 详情失败：$e');
          continue;
        }
        if (info.name.trim().isEmpty) continue;
        final ShelfBook cand = ShelfBook.fromInfo(
          info,
          sourceUrl: o.sourceUrl,
          sourceName: o.sourceName,
          type: 0,
        );
        List<BookChapter> chs;
        BookContent ct;
        final int probe;
        try {
          chs = await st.loadChapters(cand);
          if (chs.isEmpty) {
            tried.writeln('${o.sourceName}/《${info.name}》目录为空');
            continue;
          }
          probe = chs.length ~/ 2;
          ct = await st.loadContent(cand, chs[probe]);
        } catch (e) {
          tried.writeln('${o.sourceName}/《${info.name}》目录或正文失败：$e');
          continue;
        }
        tried.writeln('${o.sourceName}/《${info.name}》'
            '${chs.length} 章，第 ${probe + 1} 章 ${ct.text.trim().length} 字');
        if (ct.text.trim().length > 300) {
          novel = cand;
          novelInfo = info;
          chapters = chs;
          content = ct;
          mid = probe;
          break;
        }
      }
    }
    expect(novel, isNotNull, reason: '要有一本能读出正文的小说\n$tried');
    final ShelfBook n = novel!;
    expect(novelInfo!.name.trim(), isNotEmpty, reason: '详情页书名不能为空');
    expect(n.isComic, isFalse);

    // 4) 入架
    await st.addToShelf(n);
    expect(await st.inShelf(n.bookUrl), isTrue);
    expect(st.shelf.any((ShelfBook b) => b.bookUrl == n.bookUrl), isTrue);
    expect(chapters.first.title.trim(), isNotEmpty);

    // 5) 正文（已在上一步验证）
    expect(content!.text.trim().length, greaterThan(300),
        reason: '《${n.name}》第 ${mid + 1}/${chapters.length} 章'
            '「${chapters[mid].title}」 长度=${content.text.trim().length}');
    expect(content.text.contains('<'), isFalse, reason: '正文里不应残留 HTML 标签');

    // 6) 存进度 → 重新 bootstrap 后仍在
    await st.saveProgress(n, mid, offset: 0.42);
    final AppState st2 = AppState();
    await st2.bootstrap();
    final ShelfBook? reread = st2.shelf
        .where((ShelfBook b) => b.bookUrl == n.bookUrl)
        .firstOrNull;
    expect(reread, isNotNull);
    expect(reread!.lastReadIndex, mid);
    expect(reread.lastReadOffset, closeTo(0.42, 0.001));

    // 7) 漫画链路：找漫画源，验证 isComic 与图片可下载
    final SearchOutcome? comicOut = outcomes
        .where((SearchOutcome o) => o.ok && o.books.isNotEmpty)
        .where((SearchOutcome o) => o.books.first.type == 2)
        .firstOrNull;
    if (comicOut != null) {
      final dynamic cb = comicOut.books.first;
      final BookInfo comicInfo = await st.engine.bookInfo(
        st.sourceOf(comicOut.sourceUrl)!,
        cb.bookUrl as String,
        fallbackName: cb.name as String,
      );
      final ShelfBook comic = ShelfBook.fromInfo(
        comicInfo,
        sourceUrl: comicOut.sourceUrl,
        sourceName: comicOut.sourceName,
        type: 2,
      );
      expect(comic.isComic, isTrue, reason: '漫画源必须走漫画阅读器');

      final List<BookChapter> cchs = await st.loadChapters(comic);
      expect(cchs, isNotEmpty);
      final BookContent cct = await st.loadContent(comic, cchs.first);
      expect(cct.images, isNotEmpty, reason: '漫画章节要解析出图片');
      final Uint8List bytes =
          await st.engine.http.imageBytes(cct.images.first);
      expect(bytes.length, greaterThan(1000), reason: '图片应当真的下载得到');
      // ignore: avoid_print
      print('COMIC images=${cct.images.length} firstBytes=${bytes.length}');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
