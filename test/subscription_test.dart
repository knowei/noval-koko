import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/db/source_repo.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/source_subscription.dart';
import 'package:noval/src/source/source_engine.dart';

void main() {
  group('镜像回退', () {
    test('swapHost 只换主机名，路径与协议不动', () {
      expect(
        SourceEngine.swapHost(
          'https://baozimh.org/s?q=%E6%96%97%E7%BD%97',
          'https://baozimh.org',
          'https://bzmh.org',
        ),
        'https://bzmh.org/s?q=%E6%96%97%E7%BD%97',
      );
      // 主机相同就不动
      expect(
        SourceEngine.swapHost('https://a.com/x', 'https://a.com', 'https://a.com'),
        'https://a.com/x',
      );
    });

    test('书源没写 mirrors 时用内置对照组', () {
      const BookSource s = BookSource(
        url: 'https://baozimh.org',
        name: '包子漫画',
        type: SourceType.image,
      );
      expect(s.mirrors, contains('https://bzmh.org'));
    });

    test('书源里写了 mirrors 就用它，且滤掉自己', () {
      final BookSource s = BookSource.fromJson(<String, dynamic>{
        'bookSourceUrl': 'https://a.example',
        'bookSourceName': 'A',
        'mirrors': <String>['https://b.example', 'https://a.example', ''],
      });
      expect(s.mirrors, <String>['https://b.example']);
    });

    test('mirrors 也支持用逗号/空格写的字符串', () {
      final BookSource s = BookSource.fromJson(<String, dynamic>{
        'bookSourceUrl': 'https://a.example',
        'bookSourceName': 'A',
        'mirrors': 'https://b.example, https://c.example',
      });
      expect(s.mirrors, <String>['https://b.example', 'https://c.example']);
    });
  });

  group('书源订阅', () {
    test('JSON 往返不丢字段', () {
      const SourceSubscription sub = SourceSubscription(
        url: 'https://example.com/sources.json',
        name: '某人的源',
        count: 12,
        lastSync: 1700000000000,
      );
      final SourceSubscription back =
          SourceSubscription.fromJson(sub.toJson());
      expect(back.url, sub.url);
      expect(back.name, sub.name);
      expect(back.count, 12);
      expect(back.lastSync, 1700000000000);
    });

    test('displayName 缺名字时退回域名', () {
      const SourceSubscription sub =
          SourceSubscription(url: 'https://raw.example.org/list.json');
      expect(sub.displayName, 'raw.example.org');
      expect(sub.lastSyncText, '从未更新');
    });

    test('订阅返回的书源 JSON 能被同一条解析路径吃下', () {
      const String payload = '[{"bookSourceUrl":"https://x.example",'
          '"bookSourceName":"X","bookSourceType":0}]';
      final List<BookSource> sources = SourceRepo.parseSources(payload);
      expect(sources.length, 1);
      expect(sources.first.name, 'X');

      // Legado 分享格式：包了一层 bookSources
      const String wrapped = '{"bookSources":[{"bookSourceUrl":"https://y.example",'
          '"bookSourceName":"Y"}]}';
      final List<BookSource> sources2 = SourceRepo.parseSources(wrapped);
      expect(sources2.length, 1);
      expect(sources2.first.name, 'Y');
    });

    test('copyWithEnabled 只改开关', () {
      final BookSource s = BookSource.fromJson(<String, dynamic>{
        'bookSourceUrl': 'https://x.example',
        'bookSourceName': 'X',
        'searchUrl': '/s?q={{key}}',
      });
      final BookSource off = s.copyWithEnabled(false);
      expect(off.enabled, isFalse);
      expect(off.searchUrl, s.searchUrl);
      expect(off.name, s.name);
    });
  });
}
