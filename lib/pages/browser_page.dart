import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/download_service.dart';
import '../state/app_state.dart';
import '../util/rotary.dart';
import '../util/round_layout.dart';
import '../util/wear_bridge.dart';
import 'list_pages.dart';

const _desktopUA =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

/// 浏览器主页面：全屏 WebView + 圆屏安全区内的悬浮控制条
class BrowserPage extends StatefulWidget {
  final String initialUrl;
  const BrowserPage({super.key, required this.initialUrl});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  final _url = ValueNotifier<String>('');
  final _title = ValueNotifier<String>('');
  final _progress = ValueNotifier<int>(0);
  final _canBack = ValueNotifier<bool>(false);
  final _canFwd = ValueNotifier<bool>(false);
  final _error = ValueNotifier<String?>(null);
  InAppWebViewController? _c;

  @override
  void initState() {
    super.initState();
    Rotary.attach(_handleRotary);
    if (AppState.current?.keepScreenOn ?? false) {
      WearBridge.keepScreenOn(true);
    }
  }

  @override
  void dispose() {
    Rotary.detach(_handleRotary);
    WearBridge.keepScreenOn(false);
    _url.dispose();
    _title.dispose();
    _progress.dispose();
    _canBack.dispose();
    _canFwd.dispose();
    _error.dispose();
    super.dispose();
  }

  // ---------------- 表冠：滚动网页 ----------------
  void _handleRotary(double delta) {
    final invert = AppState.current?.crownInvert ?? false;
    final d = (invert ? -delta : delta) * 90;
    if (d == 0) return;
    _c?.evaluateJavascript(source: 'window.scrollBy(0, $d);');
  }

  // ---------------- WebView 设置（性能优先：全功能加载） ----------------
  InAppWebViewSettings _buildSettings(AppState s) => InAppWebViewSettings(
        useOnDownloadStart: true,
        useShouldOverrideUrlLoading: true,
        javaScriptEnabled: true,
        // 单窗口模式：禁止页面弹新窗口（稳定性关键，多 WebView 极易 OOM）
        supportMultipleWindows: false,
        javaScriptCanOpenWindowsAutomatically: false,
        // 缩放：支持双指/内置缩放 + 视口适配宽度
        supportZoom: true,
        builtInZoomControls: false,
        useWideViewPort: true,
        loadWithOverviewMode: true, // 1.0 缩放 = 适配宽度
        initialScale: 0,
        // 性能：开缓存加速回访，关数据库省内存
        cacheEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: false,
        geolocationEnabled: false,
        // 兼容性全开
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        thirdPartyCookiesEnabled: true,
        userAgent: s.desktopMode ? _desktopUA : null,
        transparentBackground: false,
      );

  void _applyZoom() {
    final z = AppState.current?.zoomScale ?? 1.0;
    _c?.evaluateJavascript(source: "document.documentElement.style.zoom = '$z';");
  }

  void _refreshNav() async {
    final c = _c;
    if (c == null) return;
    _canBack.value = await c.canGoBack();
    _canFwd.value = await c.canGoForward();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 2), content: Text(msg)));
  }

  // ---------------- 菜单动作 ----------------
  void _zoomStep(double step) {
    final s = AppState.current!;
    s.setZoomScale(s.zoomScale + step);
    _applyZoom();
  }

  void _zoomFit() {
    AppState.current!.setZoomScale(1.0);
    _applyZoom();
    _snack('已恢复适配宽度');
  }

  Future<void> _toggleDesktopMode(bool on) async {
    final s = AppState.current!;
    s.set('desktopMode', on);
    final c = _c;
    if (c == null) return;
    await c.setSettings(settings: _buildSettings(s));
    final u = await c.getUrl();
    if (u != null) await c.loadUrl(urlRequest: URLRequest(url: u));
    _snack(on ? '已切换为桌面模式' : '已切换为移动模式');
  }

  void _editUrlSheet() {
    final current = _url.value;
    final ctrl = TextEditingController(text: current);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20, bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('打开 / 搜索',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(hintText: '网址或关键词'),
              onSubmitted: (v) => _navigateFrom(v, ctx),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('取消')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                      onPressed: () => _navigateFrom(ctrl.text, ctx),
                      child: const Text('前往')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateFrom(String raw, BuildContext sheetCtx) {
    Navigator.of(sheetCtx).pop();
    final s = AppState.current!;
    final url = s.resolveInput(raw);
    if (url.isEmpty) return;
    _error.value = null;
    _c?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  void _openMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: AppState.current!,
        builder: (ctx, _) {
          final s = AppState.current!;
          final isBm = s.isBookmarked(_url.value);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 缩放控制
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _zoomStep(-0.1),
                        icon: const Icon(Icons.zoom_out),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _zoomFit,
                          child: Column(
                            children: [
                              Text('${(s.zoomScale * 100).round()}%',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const Text('点按恢复适配宽度',
                                  style: TextStyle(
                                      fontSize: 10, color: Color(0xFF5B6577))),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _zoomStep(0.1),
                        icon: const Icon(Icons.zoom_in),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(isBm ? Icons.star : Icons.star_border),
                  title: Text(isBm ? '移除书签' : '添加书签'),
                  onTap: () {
                    s.toggleBookmark(_url.value, _title.value);
                    Navigator.of(ctx).pop();
                    _snack(isBm ? '已移除书签' : '已加入书签');
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.desktop_windows_outlined),
                  title: const Text('桌面模式'),
                  value: s.desktopMode,
                  onChanged: (v) {
                    Navigator.of(ctx).pop();
                    _toggleDesktopMode(v);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.lightbulb_outline),
                  title: const Text('浏览时常亮'),
                  value: s.keepScreenOn,
                  onChanged: (v) {
                    s.set('keepScreenOn', v);
                    WearBridge.keepScreenOn(v);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('下载管理'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            const AppListPage(kind: ListKind.downloads)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: const Text('清除缓存'),
                  onTap: () {
                    InAppWebViewController.clearAllCache();
                    Navigator.of(ctx).pop();
                    _snack('缓存已清除');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('回到首页'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    AppScope.read(context); // 不主动重建（浏览状态用 ValueNotifier 驱动）
    final size = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;

    final topInset = insetForBand(size, 40, 92, extra: 4);
    final bottomInset = insetForBand(size, size.height - 88, size.height - 32,
        extra: 4);
    final errInset = insetForBand(size, 104, 200, extra: 4);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ---------- 网页 ----------
          Positioned.fill(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
              initialSettings: _buildSettings(AppState.current!),
              onWebViewCreated: (c) => _c = c,
              onLoadStart: (c, url) {
                _error.value = null;
                _progress.value = 0;
                if (url != null) _url.value = url.toString();
              },
              onLoadStop: (c, url) async {
                _progress.value = 100;
                final u = await c.getUrl();
                final t = await c.getTitle();
                if (u != null) _url.value = u.toString();
                _title.value = t ?? '';
                _refreshNav();
                _applyZoom();
                AppState.current?.addHistory(_url.value, _title.value);
                if (AppState.current?.keepScreenOn ?? false) {
                  WearBridge.keepScreenOn(true);
                }
              },
              onProgressChanged: (c, p) => _progress.value = p,
              onTitleChanged: (c, t) => _title.value = t ?? '',
              onUpdateVisitedHistory: (c, url, isReload) {
                if (url != null) _url.value = url.toString();
                _refreshNav();
              },
              onReceivedError: (c, request, error) {
                if (request.isForMainFrame == true) {
                  _error.value = error.description;
                }
              },
              onDownloadStartRequest: (c, req) async {
                await DownloadService.instance.start(
                  url: req.url.toString(),
                  fileName: req.suggestedFilename,
                  userAgent: req.userAgent,
                  totalBytes: req.contentLength,
                );
                _snack('已加入下载队列');
              },
              shouldOverrideUrlLoading: (c, action) async {
                final schemeName =
                    Uri.tryParse(action.request.url.toString())?.scheme ?? '';
                final s = schemeName.toLowerCase();
                if (s == 'http' ||
                    s == 'https' ||
                    s == 'about' ||
                    s == 'data' ||
                    s == 'blob') {
                  return NavigationActionPolicy.ALLOW;
                }
                _snack('已拦截外部链接 ($s:)');
                return NavigationActionPolicy.CANCEL;
              },
            ),
          ),

          // ---------- 顶部：URL 胶囊 + 进度 ----------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: const Color(0xF205080F),
              padding:
                  EdgeInsets.only(top: 40, left: topInset, right: topInset),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _editUrlSheet,
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              children: [
                                ValueListenableBuilder<bool>(
                                  valueListenable: _canBack,
                                  builder: (_, _, _) => Icon(
                                        Icons.public,
                                        size: 16,
                                        color: scheme.primary,
                                      ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ValueListenableBuilder<String>(
                                    valueListenable: _url,
                                    builder: (_, u, _) {
                                      final host = Uri.tryParse(u)?.host;
                                      return Text(
                                        host == null || host.isEmpty
                                            ? (u.isEmpty ? '输入网址…' : u)
                                            : host,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                      );
                                    },
                                  ),
                                ),
                                ValueListenableBuilder<String>(
                                  valueListenable: _title,
                                  builder: (_, t, _) => t.isEmpty
                                      ? const SizedBox.shrink()
                                      : const Icon(Icons.chevron_right,
                                          size: 16, color: Color(0xFF5B6577)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 加载进度条
                  ValueListenableBuilder<int>(
                    valueListenable: _progress,
                    builder: (_, p, _) => AnimatedOpacity(
                      opacity: (p > 0 && p < 100) ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: SizedBox(
                        height: 3,
                        child: LinearProgressIndicator(
                            value: p > 0 && p < 100 ? p / 100 : null),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),

          // ---------- 错误横幅 ----------
          ValueListenableBuilder<String?>(
            valueListenable: _error,
            builder: (_, err, _) {
              if (err == null) return const SizedBox.shrink();
              return Positioned(
                top: 104,
                left: errInset,
                right: errInset,
                child: Card(
                  color: scheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '页面加载失败：$err',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onErrorContainer),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                _error.value = null;
                                _c?.reload();
                              },
                              child: const Text('重试'),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => _error.value = null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // ---------- 底部控制条 ----------
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: const Color(0xF205080F),
              padding: EdgeInsets.only(
                  left: bottomInset, right: bottomInset, bottom: 32),
              child: ValueListenableBuilder2<bool, bool>(
                valueListenable: _canBack,
                valueListenable2: _canFwd,
                builder: (_, back, fwd, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton.filledTonal(
                      onPressed: back
                          ? () {
                              _c?.goBack();
                              Future.microtask(_refreshNav);
                            }
                          : null,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    IconButton.filledTonal(
                      onPressed: fwd
                          ? () {
                              _c?.goForward();
                              Future.microtask(_refreshNav);
                            }
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _progress,
                      builder: (_, p, _) {
                        final loading = p > 0 && p < 100;
                        return IconButton.filledTonal(
                          onPressed: () {
                            if (loading) {
                              _c?.stopLoading();
                            } else {
                              _c?.reload();
                            }
                          },
                          icon: Icon(loading ? Icons.close : Icons.refresh),
                        );
                      },
                    ),
                    IconButton.filledTonal(
                      onPressed: _openMenu,
                      icon: const Icon(Icons.more_horiz),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 两个 ValueNotifier 的组合监听（避免引入额外依赖）
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> valueListenable;
  final ValueListenable<B> valueListenable2;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  const ValueListenableBuilder2({
    super.key,
    required this.valueListenable,
    required this.valueListenable2,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: valueListenable,
      builder: (ctx, a, _) => ValueListenableBuilder<B>(
        valueListenable: valueListenable2,
        builder: (ctx2, b, _) => builder(ctx, a, b, null),
      ),
    );
  }
}
