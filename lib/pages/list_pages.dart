import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/download_service.dart';
import '../state/app_state.dart';
import '../util/rotary.dart';
import '../util/round_layout.dart';
import '../widgets/round_header.dart';
import 'browser_page.dart';

enum ListKind { bookmarks, history, downloads }

/// 书签 / 历史 / 下载 三个列表页
class AppListPage extends StatefulWidget {
  final ListKind kind;
  const AppListPage({super.key, required this.kind});

  @override
  State<AppListPage> createState() => _AppListPageState();
}

class _AppListPageState extends State<AppListPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _openUrl(String url) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BrowserPage(initialUrl: url)));
  }

  String get _title => switch (widget.kind) {
        ListKind.bookmarks => '书签',
        ListKind.history => '历史',
        ListKind.downloads => '下载',
      };

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final listInset = insetForBand(size, 100, size.height - 48, extra: 4);

    return Scaffold(
      body: Column(
        children: [
          RoundHeader(
            title: _title,
            actions: widget.kind == ListKind.history
                ? [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '清空',
                      icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                      onPressed: _clearHistory,
                    )
                  ]
                : const [],
          ),
          Expanded(
            child: switch (widget.kind) {
              ListKind.bookmarks => _buildBookmarks(listInset),
              ListKind.history => _buildHistory(listInset),
              ListKind.downloads => _buildDownloads(listInset),
            },
          ),
        ],
      ),
    );
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空历史？'),
        content: const Text('将删除全部浏览历史记录。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消')),
          FilledButton(
            onPressed: () {
              AppScope.read(context).clearHistory();
              Navigator.of(ctx).pop();
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Center(
      child: Text(text,
          style: const TextStyle(fontSize: 13, color: Color(0xFF5B6577))),
    );
  }

  // ---------------- 书签 ----------------
  Widget _buildBookmarks(double inset) {
    final s = AppScope.of(context);
    if (s.bookmarks.isEmpty) return _empty('暂无书签\n浏览时点菜单 → 添加书签');
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(inset, 8, inset, 32),
      itemCount: s.bookmarks.length,
      itemBuilder: (ctx, i) {
        final b = s.bookmarks[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.star, size: 18),
            title: Text(b.title,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
            subtitle: Text(Uri.tryParse(b.url)?.host ?? b.url,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10)),
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => s.removeBookmark(b.url),
            ),
            onTap: () => _openUrl(b.url),
          ),
        );
      },
    );
  }

  // ---------------- 历史 ----------------
  Widget _buildHistory(double inset) {
    final s = AppScope.of(context);
    if (s.history.isEmpty) return _empty('暂无浏览历史');
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(inset, 8, inset, 32),
      itemCount: s.history.length,
      itemBuilder: (ctx, i) {
        final h = s.history[i];
        final dt = DateTime.fromMillisecondsSinceEpoch(h.ts);
        final time =
            '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.history, size: 18),
            title: Text(h.title,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
            subtitle: Text('${Uri.tryParse(h.url)?.host ?? ''} · $time',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10)),
            onTap: () => _openUrl(h.url),
          ),
        );
      },
    );
  }

  // ---------------- 下载 ----------------
  Widget _buildDownloads(double inset) {
    return AnimatedBuilder(
      animation: DownloadService.instance,
      builder: (ctx, _) {
        final ds = DownloadService.instance;
        if (ds.tasks.isEmpty) {
          return _empty('暂无下载\n网页中的文件下载会出现在这里');
        }
        return FutureBuilder<String>(
          future: ds.directoryPath(),
          builder: (ctx2, snap) => ListView.builder(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(inset, 8, inset, 32),
            itemCount: ds.tasks.length + 1,
            itemBuilder: (ctx3, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
                  child: Text(
                    '保存目录：${snap.data ?? '…'}',
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFF5B6577)),
                  ),
                );
              }
              final t = ds.tasks[i - 1];
              return _DownloadTile(task: t, ds: ds);
            },
          ),
        );
      },
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadTask task;
  final DownloadService ds;
  const _DownloadTile({required this.task, required this.ds});

  @override
  Widget build(BuildContext context) {
    final running = task.status == DownloadStatus.running;
    final scheme = Theme.of(context).colorScheme;

    final IconData icon;
    final String status;
    switch (task.status) {
      case DownloadStatus.running:
        icon = Icons.downloading;
        status = task.sizeText;
      case DownloadStatus.done:
        icon = Icons.check_circle;
        status = '完成 · ${task.sizeText}（点按复制路径）';
      case DownloadStatus.failed:
        icon = Icons.error;
        status = '失败${task.error == null ? '' : '：${task.error}'}';
      case DownloadStatus.canceled:
        icon = Icons.cancel;
        status = '已取消';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: running
            ? null
            : () async {
                if (task.status == DownloadStatus.done) {
                  await Clipboard.setData(ClipboardData(
                      text:
                          '${(await ds.directoryPath())}/${task.fileName}'));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        duration: Duration(seconds: 2),
                        content: Text('路径已复制')));
                  }
                }
              },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 18,
                      color: task.status == DownloadStatus.failed
                          ? scheme.error
                          : scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(task.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  if (running)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => ds.cancel(task.id),
                    )
                  else if (task.status != DownloadStatus.done)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: () => ds.retry(task.id),
                    ),
                  if (!running)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => ds.remove(task.id),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10,
                        color: task.status == DownloadStatus.failed
                            ? scheme.error
                            : const Color(0xFF5B6577))),
              ),
              if (running)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task.progress,
                      minHeight: 4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
