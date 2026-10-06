import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'util/rotary.dart';
import 'util/wear_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WearBridge.init();
  Rotary.init();
  final state = await AppState.load();
  runApp(WatchBrowserApp(state: state));
}

class WatchBrowserApp extends StatelessWidget {
  final AppState state;
  const WatchBrowserApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    // AppScope 放在 MaterialApp 外层：所有 push 出来的路由都能访问
    return AppScope(
      state: state,
      child: MaterialApp(
        title: '圆表浏览器',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomePage(),
      ),
    );
  }
}
