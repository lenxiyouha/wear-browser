import 'package:flutter/material.dart';

import '../pages/browser_page.dart';
import '../pages/list_pages.dart';
import '../pages/settings_page.dart';
import '../services/download_service.dart';
import '../state/app_state.dart';
import '../util/rotary.dart';
import '../util/round_layout.dart';

/// 圆屏常驻快速访问站点
class QuickSite {
  final String name;
  final String url;
  const QuickSite(this.name, this.url);
}

const kQuickSites = [
  QuickSite('百度', 'https://www.baidu.com'),
  QuickSite('必应', 'https://cn.bing.com'),
  QuickSite('维基', 'https://zh.wikipedia.org'),
  QuickSite('微博', 'https://m.weibo.cn'),
  QuickSite('贴吧', 'https://tieba.baidu.com'),
  QuickSite('GitHub', 'https://github.com'),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scroll = ScrollController();
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 表冠滚动列表（方向设置实时读取）
    Rotary.attach(_handleRotary);
  }

  void _handleRotary(double delta) {
    final invert = AppState.current?.crownInvert ?? false;
    scrollListBy(_scroll, invert ? -delta : delta);
  }

  @override
  void dispose() {
    Rotary.detach(_handleRotary);
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  void _open(String raw) {
    final s = AppScope.read(context);
    final url = s.resolveInput(raw);
    if (url.isEmpty) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BrowserPage(initialUrl: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context); // 监听设置/书签/历史变化
    final size = MediaQuery.sizeOf(context);

    // 可见带：标题区 [40,92]，列表 [100, H-96]
    final headerInset = insetForBand(size, 40, 92, extra: 4);
    final listInset = insetForBand(size, 100, size.height - 96, extra: 4);

    return Scaffold(
      body: Column(
        children: [
          // ---------- 顶部标题（不透明，列表滚上去藏在后面） ----------
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
                top: 40, left: headerInset, right: headerInset, bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.travel_explore, size: 20,
                    color: Color(0xFF22D3EE)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('圆表浏览器',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.settings_outlined, size: 22),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage())),
                ),
              ],
            ),
          ),

          // ---------- 列表 ----------
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                  listInset, 8, listInset, size.height * 0.12),
              children: [
                // 搜索 / 地址栏
                TextField(
                  controller: _input,
                  textInputAction: TextInputAction.go,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '输入网址或搜索…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward, size: 20),
                      onPressed: () => _open(_input.text),
                    ),
                  ),
                  onSubmitted: _open,
                ),
                const SizedBox(height: 16),

                _SectionTitle('快速访问'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final site in kQuickSites)
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _open(site.url),
                        child: Text(site.name),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                _SectionTitle('数据'),
                const SizedBox(height: 8),
                _EntryCard(
                  icon: Icons.star_outline,
                  title: '书签',
                  badge: '${s.bookmarks.length}',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AppListPage(kind: ListKind.bookmarks))),
                ),
                const SizedBox(height: 8),
                _EntryCard(
                  icon: Icons.history,
                  title: '历史',
                  badge: '${s.history.length}',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AppListPage(kind: ListKind.history))),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: DownloadService.instance,
                  builder: (context, _) {
                    final ds = DownloadService.instance;
                    return _EntryCard(
                      icon: Icons.download_outlined,
                      title: '下载',
                      badge: ds.activeCount > 0
                          ? '${ds.activeCount} 进行中'
                          : '${ds.tasks.length}',
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AppListPage(kind: ListKind.downloads))),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    '圆表浏览器 v1.0 · 为圆形手表优化',
                    style: TextStyle(fontSize: 11, color: Color(0xFF5B6577)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String badge;
  final VoidCallback onTap;

  const _EntryCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Text(badge,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
