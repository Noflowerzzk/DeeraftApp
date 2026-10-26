import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'src/state.dart';
import 'src/screens.dart';
import 'src/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: DeeraftApp()));
}

final _router = GoRouter(
  routes: [GoRoute(path: '/', builder: (_, _) => const AppGate())],
);

class DeeraftApp extends StatelessWidget {
  const DeeraftApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Deeraft',
    debugShowCheckedModeBanner: false,
    theme: appTheme,
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
