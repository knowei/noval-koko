// 只在「真实 App 运行时」验证：JS 引擎依赖 quickjs 原生库，普通 flutter test
// 加载不到，必须用 integration_test 在桌面上跑：
//
//   flutter test integration_test/js_engine_test.dart -d windows
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/rule/js_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('JS 引擎在桌面运行时可用', (WidgetTester tester) async {
    final JsEngine js = JsEngine(fetch: (JsRequest r) async => '');
    try {
      expect(await js.runString("'a' + 'b'"), 'ab');
      expect(await js.runString('(1 + 2) * 3'), '9');
      expect(await js.runString('"x".toUpperCase()'), 'X');
      expect(await js.runString('result', result: 'hello'), 'hello');
    } finally {
      js.dispose();
    }
  });

  testWidgets('java.ajax 通过异步取数再重放', (WidgetTester tester) async {
    final List<String> fetched = <String>[];
    final JsEngine js = JsEngine(fetch: (JsRequest r) async {
      fetched.add(r.url);
      return 'FETCHED:${r.url}';
    });
    try {
      final String out = await js.runString("java.ajax('http://example.com/a')");
      expect(out, 'FETCHED:http://example.com/a');
      expect(fetched, <String>['http://example.com/a']);
    } finally {
      js.dispose();
    }
  });

  testWidgets('java.base64 / md5 等内置函数', (WidgetTester tester) async {
    final JsEngine js = JsEngine(fetch: (JsRequest r) async => '');
    try {
      expect(await js.runString("java.base64Encode('abc')"), 'YWJj');
      expect(await js.runString("java.base64Decode('YWJj')"), 'abc');
      expect(await js.runString("java.md5Encode('abc')"),
          '900150983cd24fb0d6963f7d28e17f72');
    } finally {
      js.dispose();
    }
  });
}
