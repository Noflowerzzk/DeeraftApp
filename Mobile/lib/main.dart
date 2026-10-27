import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'src/state.dart';
import 'src/screens.dart';
import 'src/theme.dart';
import 'src/appearance.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: DeeraftApp()));
}

final _router = GoRouter(
  routes: [GoRoute(path: '/', builder: (_, _) => const AppGate())],
);

class DeeraftApp extends ConsumerWidget {
  const DeeraftApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'DeeraftApp',
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    darkTheme: appDarkTheme,
    themeMode: ref.watch(appearanceProvider),
    routerConfig: _router,
  );
}

class AppGate extends ConsumerWidget {
  const AppGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    if (state.booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return state.user == null ? const LoginScreen() : const CommunityShell();
  }
}
