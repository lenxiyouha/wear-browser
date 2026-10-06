import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 圆形屏幕几何工具。
///
/// 物理面板是圆的，落在圆外的内容会被直接裁掉。
/// 这里按「可见纵向区间」计算左右最小内边距，
/// 保证排版元素（图标/文字/按钮）始终落在圆内。

double circleRadius(Size s) => math.min(s.width, s.height) / 2;

/// 圆在纵向位置 y 处的半宽
double circleHalfWidthAt(Size s, double y) {
  final r = circleRadius(s);
  final cy = s.height / 2;
  final dy = (y - cy).abs();
  if (dy >= r) return 0;
  return math.sqrt(r * r - dy * dy);
}

/// 可见区间 [yTop, yBottom] 内、为保证内容不被裁掉所需的水平内边距。
/// 区间两端离圆心最远、半宽最小，所以取两端的最坏情况。
double insetForBand(Size s, double yTop, double yBottom, {double extra = 0}) {
  final cx = s.width / 2;
  final hwTop = circleHalfWidthAt(s, yTop);
  final hwBottom = circleHalfWidthAt(s, yBottom);
  final worstHalf = math.min(hwTop, hwBottom);
  final inset = cx - worstHalf + extra;
  return inset.clamp(0.0, cx);
}

/// 给某个纵向带状区域生成水平内边距（用于 Padding / contentPadding）
EdgeInsets bandInsets(
  BuildContext context, {
  required double top,
  required double bottom,
  double extra = 0,
}) {
  final size = MediaQuery.sizeOf(context);
  final p = insetForBand(size, top, size.height - bottom, extra: extra);
  return EdgeInsets.only(left: p, right: p, top: top, bottom: bottom);
}
