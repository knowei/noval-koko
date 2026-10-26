import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/rule/js_engine.dart';

/// 验证两件事：
/// 1. 规则 JS 返回 Promise 时，引擎能等到最终结果（evaluateAsync 路径）；
/// 2. 包子漫画的图片解密脚本（整段浏览器脚本，挂到 window 上）能在 QuickJS 里跑通。
void main() {
  test('规则返回 Promise 时能拿到 resolve 后的值', () async {
    final JsEngine engine = JsEngine(fetch: (JsRequest r) async => '');
    final String out = await engine.runString('''
var p = Promise.resolve('done-' + (1 + 1));
p;
''');
    expect(out.trim(), 'done-2');
    engine.dispose();
  });

  test('包子漫画图片解密器可在 QuickJS 内运行', () async {
    final File decoder = File('tool/bz_decoder.js');
    final File payloadFile = File('tool/bz_payload.json');
    expect(decoder.existsSync(), isTrue, reason: '缺少 tool/bz_decoder.js');
    expect(payloadFile.existsSync(), isTrue, reason: '缺少 tool/bz_payload.json');

    final String src = decoder.readAsStringSync();
    final String payload = payloadFile.readAsStringSync().trim();

    final JsEngine engine = JsEngine(fetch: (JsRequest r) async => '');
    final List<String> urls = await engine.run(
      '''
$src
window.__cimg.r($payload).then(function (list) {
  return list.map(function (it) { return it.url; });
});
''',
      // 解密脚本会校验 location.hostname 白名单，baseUrl 必须是站点自己的地址。
      baseUrl: 'https://baozimh.org/manga/douluodalu-fengxuandongman/133-6572120-302',
    );
    engine.dispose();

    // ignore: avoid_print
    print('解出 ${urls.length} 张：${urls.take(3).toList()}');
    expect(urls.length, 36);
    expect(urls.first, startsWith('/coco/'));
  });
}
