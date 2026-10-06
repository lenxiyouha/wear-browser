import 'package:flutter/material.dart';

import '../util/round_layout.dart';

/// 圆屏安全区内的页面头部（标题 + 返回 + 操作按钮）
class RoundHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget> actions;

  const RoundHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final inset = insetForBand(size, 40, 92, extra: 4);

    return Container(
      width: double.infinity,
      color: const Color(0xF205080F),
      padding: EdgeInsets.only(top: 40, left: inset, right: inset, bottom: 4),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF5B6577)),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
