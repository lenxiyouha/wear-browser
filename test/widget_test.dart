import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wear_browser/main.dart';
import 'package:wear_browser/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppState 基础逻辑', () {
    test('输入解析：网址 vs 搜索', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await AppState.load();

      expect(s.resolveInput('https://example.com'), 'https://example.com');
      expect(s.resolveInput('example.com'), 'https://example.com');
      expect(s.resolveInput('m.baidu.com'), 'https://m.baidu.com');
      expect(s.resolveInput('flutter 圆形手表'),
          SearchEngine.baidu.buildUrl('flutter 圆形手表'));
      expect(s.resolveInput('   '), '');
    });

    test('历史去重 + 上限裁剪', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await AppState.load();
      s.clearHistory();

      s.addHistory('https://a.com', 'A');
      s.addHistory('https://b.com', 'B');
      s.addHistory('https://a.com', 'A2');
      expect(s.history.length, 2);
      expect(s.history.first.url, 'https://a.com');
      expect(s.history.first.title, 'A2');

      for (var i = 0; i < AppState.historyCap + 50; i++) {
        s.addHistory('https://x$i.com', 'X$i');
      }
      expect(s.history.length, AppState.historyCap);
    });

    test('书签切换', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await AppState.load();
      s.removeBookmark('https://flutter.dev');
      expect(s.isBookmarked('https://flutter.dev'), isFalse);

      s.toggleBookmark('https://flutter.dev', 'Flutter');
      expect(s.isBookmarked('https://flutter.dev'), isTrue);
      expect(s.bookmarks.first.title, 'Flutter');

      s.toggleBookmark('https://flutter.dev', 'Flutter');
      expect(s.isBookmarked('https://flutter.dev'), isFalse);
    });

    test('缩放范围钳制', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await AppState.load();
      s.setZoomScale(9.9);
      expect(s.zoomScale, 2.0);
      s.setZoomScale(0.1);
      expect(s.zoomScale, 0.5);
    });
  });

  testWidgets('应用冒烟：首页渲染搜索栏与快速访问', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();
    await tester.pumpWidget(WatchBrowserApp(state: state));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('圆表浏览器'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('快速访问'), findsOneWidget);
    expect(find.text('百度'), findsOneWidget);
    expect(find.text('书签'), findsOneWidget);
  });
}
