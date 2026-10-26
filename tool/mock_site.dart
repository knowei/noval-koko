// 本地假站点入口：没有外网、没有真实书源时用它验证整条链路。
//
//   dart run tool/mock_site.dart
//   → http://127.0.0.1:8787
//
// 然后在 App 的「书源」页导入 docs/mock_source.json 即可搜索、阅读。
import 'dart:io';

import 'mock_site_server.dart';

Future<void> main(List<String> args) async {
  final int port = args.isNotEmpty ? int.tryParse(args.first) ?? 8787 : 8787;
  final MockSite site = await MockSite.start(port: port);
  stdout.writeln('mock site: ${site.url}');
  stdout.writeln('把 docs/mock_source.json 导入 App 的「书源」页');
  stdout.writeln('按 Ctrl+C 退出');
  await ProcessSignal.sigint.watch().first;
  await site.close();
  exit(0);
}
