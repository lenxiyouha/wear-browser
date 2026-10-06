import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 搜索引擎
enum SearchEngine {
  baidu('百度', 'https://www.baidu.com/s?wd='),
  bing('必应', 'https://cn.bing.com/search?q='),
  google('谷歌', 'https://www.google.com/search?q=');

  final String label;
  final String prefix;
  const SearchEngine(this.label, this.prefix);

  String buildUrl(String query) => '$prefix${Uri.encodeComponent(query)}';
}

class Bookmark {
  final String url;
  final String title;
  const Bookmark({required this.url, required this.title});
}

class HistoryEntry {
  final String url;
  final String title;
  final int ts;
  const HistoryEntry({required this.url, required this.title, required this.ts});
}

/// 全局应用状态：设置 + 书签 + 历史（ChangeNotifier + 本地持久化）
class AppState extends ChangeNotifier {
  /// 全局访问点（InheritedNotifier 负责 UI 重建，这里负责逻辑访问）
  static AppState? current;

  late SharedPreferences _prefs;

  // ---------- 设置 ----------
  SearchEngine engine = SearchEngine.baidu;
  double zoomScale = 1.0; // 页面缩放 0.5 ~ 2.0（1.0 = 适配宽度）
  bool crownInvert = false; // 表冠方向反转
  bool keepScreenOn = true; // 浏览时常亮
  bool desktopMode = false; // 桌面 UA

  // ---------- 书签 / 历史 ----------
  final List<Bookmark> bookmarks = [];
  final List<HistoryEntry> history = [];

  static const int historyCap = 300;
  static const String _kEngine = 'engine';
  static const String _kZoom = 'zoom';
  static const String _kCrown = 'crownInvert';
  static const String _kKeepOn = 'keepScreenOn';
  static const String _kDesktop = 'desktopMode';
  static const String _kBookmarks = 'bookmarks';
  static const String _kHistory = 'history';

  AppState._();

  static Future<AppState> load() async {
    final s = AppState._();
    s._prefs = await SharedPreferences.getInstance();
    s.engine = SearchEngine.values[s._prefs.getInt(_kEngine) ?? 0];
    s.zoomScale = (s._prefs.getDouble(_kZoom) ?? 1.0).clamp(0.5, 2.0);
    s.crownInvert = s._prefs.getBool(_kCrown) ?? false;
    s.keepScreenOn = s._prefs.getBool(_kKeepOn) ?? true;
    s.desktopMode = s._prefs.getBool(_kDesktop) ?? false;
    s._loadBookmarks();
    s._loadHistory();
    current = s;
    return s;
  }

  void _loadBookmarks() {
    final raw = _prefs.getString(_kBookmarks);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      bookmarks
        ..clear()
        ..addAll(list.map((e) => Bookmark(
              url: e['url'] as String,
              title: e['title'] as String? ?? e['url'] as String,
            )));
    } catch (_) {
      // 数据损坏时放弃读取，不影响启动
    }
  }

  void _loadHistory() {
    final raw = _prefs.getString(_kHistory);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      history
        ..clear()
        ..addAll(list.map((e) => HistoryEntry(
              url: e['url'] as String,
              title: e['title'] as String? ?? e['url'] as String,
              ts: (e['ts'] as num?)?.toInt() ?? 0,
            )));
    } catch (_) {
      // ignore
    }
  }

  void _persist() {
    _prefs.setInt(_kEngine, engine.index);
    _prefs.setDouble(_kZoom, zoomScale);
    _prefs.setBool(_kCrown, crownInvert);
    _prefs.setBool(_kKeepOn, keepScreenOn);
    _prefs.setBool(_kDesktop, desktopMode);
    _prefs.setString(_kBookmarks, jsonEncode(
        bookmarks.map((b) => {'url': b.url, 'title': b.title}).toList()));
    _prefs.setString(_kHistory, jsonEncode(history
        .map((h) => {'url': h.url, 'title': h.title, 'ts': h.ts})
        .toList()));
  }

  // ---------- URL 解析：像网址就打开，否则搜索 ----------
  String resolveInput(String input) {
    final t = input.trim();
    if (t.isEmpty) return '';
    if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://').hasMatch(t)) return t;
    final noSpace = !t.contains(' ');
    final looksHost = t.contains('.') &&
        !t.endsWith('.') &&
        !t.endsWith('/') &&
        (t.length <= 84);
    if (noSpace && looksHost) return 'https://$t';
    if (t == 'localhost') return 'http://localhost';
    return engine.buildUrl(t);
  }

  // ---------- 历史 ----------
  void addHistory(String url, String? title) {
    if (url.startsWith('about:') || url.startsWith('data:')) return;
    history.removeWhere((h) => h.url == url);
    history.insert(
        0, HistoryEntry(url: url, title: title ?? url, ts: DateTime.now().millisecondsSinceEpoch));
    if (history.length > historyCap) history.removeRange(historyCap, history.length);
    _persist();
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    _persist();
    notifyListeners();
  }

  // ---------- 书签 ----------
  bool isBookmarked(String url) => bookmarks.any((b) => b.url == url);

  void toggleBookmark(String url, String title) {
    if (isBookmarked(url)) {
      bookmarks.removeWhere((b) => b.url == url);
    } else {
      bookmarks.insert(0, Bookmark(url: url, title: title.isNotEmpty ? title : url));
    }
    _persist();
    notifyListeners();
  }

  void removeBookmark(String url) {
    bookmarks.removeWhere((b) => b.url == url);
    _persist();
    notifyListeners();
  }

  // ---------- setters ----------
  void setEngine(SearchEngine e) {
    engine = e;
    _persist();
    notifyListeners();
  }

  void setZoomScale(double z) {
    zoomScale = z.clamp(0.5, 2.0);
    _persist();
    notifyListeners();
  }

  void set(String key, bool value) {
    switch (key) {
      case 'crownInvert':
        crownInvert = value;
      case 'keepScreenOn':
        keepScreenOn = value;
      case 'desktopMode':
        desktopMode = value;
    }
    _persist();
    notifyListeners();
  }
}

/// InheritedNotifier：让子树监听 AppState 变化
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }

  /// 不触发重建的只读访问
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}
