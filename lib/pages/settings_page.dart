import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../util/round_layout.dart';
import '../widgets/round_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final size = MediaQuery.sizeOf(context);
    final inset = insetForBand(size, 100, size.height - 48, extra: 4);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          const RoundHeader(title: '设置'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(inset, 8, inset, 32),
              children: [
                Card(
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.search, size: 20),
                    title: const Text('搜索引擎',
                        style: TextStyle(fontSize: 14)),
                    subtitle: Text(s.engine.label,
                        style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _pickEngine(context, s),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: SwitchListTile(
                    dense: true,
                    secondary: const Icon(Icons.rotate_90_degrees_cw_outlined,
                        size: 20),
                    title: const Text('表冠方向反转',
                        style: TextStyle(fontSize: 14)),
                    value: s.crownInvert,
                    onChanged: (v) => s.set('crownInvert', v),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: SwitchListTile(
                    dense: true,
                    secondary:
                        const Icon(Icons.lightbulb_outline, size: 20),
                    title:
                        const Text('浏览时常亮', style: TextStyle(fontSize: 14)),
                    value: s.keepScreenOn,
                    onChanged: (v) => s.set('keepScreenOn', v),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: SwitchListTile(
                    dense: true,
                    secondary: const Icon(Icons.desktop_windows_outlined,
                        size: 20),
                    title: const Text('桌面模式（默认）',
                        style: TextStyle(fontSize: 14)),
                    subtitle: const Text('新页面使用桌面 User-Agent',
                        style: TextStyle(fontSize: 10)),
                    value: s.desktopMode,
                    onChanged: (v) => s.set('desktopMode', v),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.delete_outline, size: 20),
                    title: const Text('清除浏览历史',
                        style: TextStyle(fontSize: 14)),
                    trailing: Text('${s.history.length} 条',
                        style: const TextStyle(fontSize: 11)),
                    onTap: () async {
                      final ok = await _confirm(context, '清除历史？',
                          '删除全部 ${s.history.length} 条浏览记录');
                      if (ok) {
                        s.clearHistory();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  duration: Duration(seconds: 2),
                                  content: Text('历史已清除')));
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.info_outline, size: 20,
                        color: scheme.primary),
                    title: const Text('关于圆表浏览器',
                        style: TextStyle(fontSize: 14)),
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: '圆表浏览器',
                      applicationVersion: 'v1.0',
                      applicationLegalese:
                          '为圆形 Wear OS 手表优化的轻量浏览器\n系统 WebView 内核 · MIT License',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '点击缩放百分比可恢复适配宽度',
                    style: TextStyle(fontSize: 11, color: scheme.outline),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(BuildContext ctx, String title, String msg) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('确定')),
        ],
      ),
    );
    return ok ?? false;
  }

  void _pickEngine(BuildContext ctx, AppState s) {
    showDialog(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('搜索引擎', style: TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in SearchEngine.values)
              ListTile(
                dense: true,
                title: Text(e.label, style: const TextStyle(fontSize: 14)),
                trailing: e == s.engine
                    ? Icon(Icons.check, size: 18, color: s.colorOf(ctx))
                    : null,
                onTap: () {
                  s.setEngine(e);
                  Navigator.of(d).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

extension on AppState {
  Color colorOf(BuildContext ctx) => Theme.of(ctx).colorScheme.primary;
}
