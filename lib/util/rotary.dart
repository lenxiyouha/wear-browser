import 'package:flutter/material.dart';

import 'wear_bridge.dart';

/// 表冠事件路由（控制器栈）。
///
/// 页面 push 时 attach 自己的处理器，pop 时 detach。
/// 栈顶始终是当前最上层页面的处理器，表冠事件只驱动它；
/// 子页面 pop 后，下层页面自动恢复为栈顶。
class Rotary {
  static final List<void Function(double)> _stack = [];

  static void attach(void Function(double) handler) {
    _stack.remove(handler);
    _stack.add(handler);
  }

  static void detach(void Function(double) handler) {
    _stack.remove(handler);
  }

  static void handle(double delta) {
    if (_stack.isEmpty) return;
    _stack.last(delta);
  }

  /// 初始化，接通原生表冠事件
  static void init() {
    WearBridge.onRotary = handle;
  }
}

/// 列表滚动工具：每格表冠滚动 56 逻辑像素，带平滑动画
void scrollListBy(ScrollController controller, double delta,
    {double pixelsPerDetent = 56}) {
  if (!controller.hasClients) return;
  final position = controller.position;
  final target = (position.pixels + delta * pixelsPerDetent)
      .clamp(position.minScrollExtent, position.maxScrollExtent)
      .toDouble();
  if ((target - position.pixels).abs() < 0.5) return;
  position.animateTo(
    target,
    duration: const Duration(milliseconds: 100),
    curve: Curves.easeOut,
  );
}
