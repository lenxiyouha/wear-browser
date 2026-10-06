import 'package:flutter/material.dart';

/// MD3 深色主题（手表 OLED 友好 + 青色科技感种子色）
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF22D3EE), // 青色（浏览器/网络意象）
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF05080F),
    splashFactory: InkSparkle.splashFactory,

    // 圆角卡片
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
    ),

    // 输入框：全圆角胶囊（URL/搜索栏）
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      iconColor: Color(0xFF8BE9FD),
    ),

    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
      labelStyle: const TextStyle(fontSize: 12),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentTextStyle: TextStyle(color: scheme.onSurface, fontSize: 13),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF10141C),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: false,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      linearTrackColor: Color(0xFF1A2130),
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.4),
      thickness: 0.7,
    ),
  );
}
