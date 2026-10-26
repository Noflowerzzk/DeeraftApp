import 'dart:async';

import 'package:deeraft/src/appearance.dart';
import 'package:deeraft/src/state.dart';
import 'package:deeraft/src/screens.dart';
import 'package:deeraft/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'appearance persists independently of logout and restores on restart',
    () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      expect(first.read(appearanceProvider), ThemeMode.system);
      await first.read(appearanceProvider.notifier).select(ThemeMode.dark);
      await first.read(apiProvider).clearToken();
      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      final restored = Completer<ThemeMode>();
      restarted.listen(appearanceProvider, (_, next) {
        if (next == ThemeMode.dark && !restored.isCompleted) {
          restored.complete(next);
        }
      });
      expect(
        await restored.future.timeout(const Duration(seconds: 2)),
        ThemeMode.dark,
      );
      await restarted.read(appearanceProvider.notifier).select(ThemeMode.light);
      expect(restarted.read(appearanceProvider), ThemeMode.light);
      await restarted
          .read(appearanceProvider.notifier)
          .select(ThemeMode.system);
      expect(restarted.read(appearanceProvider), ThemeMode.system);
    },
  );
  testWidgets('settings changes the actual app theme for all three choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (_, ref, _) => MaterialApp(
            theme: appTheme,
            darkTheme: appDarkTheme,
            themeMode: ref.watch(appearanceProvider),
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.light,
    );
    await tester.tap(find.text('跟随系统'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    expect(tester.takeException(), isNull);
  });
}
