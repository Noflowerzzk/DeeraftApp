import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deeraft/src/demo.dart';
import 'package:deeraft/src/models.dart';
import 'package:deeraft/src/screens.dart';
import 'package:deeraft/src/state.dart';
import 'package:deeraft/src/theme.dart';

class DemoController extends AppController {
  @override
  AppState build() => AppState()
    ..booting = false
    ..demo = true
    ..user = const UserProfile(username: 'Noflowerzzk', bio: '一起探索世界。')
    ..community = CommunityStatus.fromJson(
      demoCommunity()..['fetched_at'] = '2026-10-26T06:30:00Z',
    )
    ..servers = demoServers
    ..chat = demoChat
    ..hostedStatus = {'is_running': true, 'server_name': 'SSCG26.3'}
    ..chatConnection = '演示数据';
  @override
  Future<void> refresh() async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('NotoSansSC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansSC.ttf'));
    await loader.load();
    final latin = FontLoader('DMSans')
      ..addFont(rootBundle.load('assets/fonts/DMSans.ttf'));
    await latin.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('mobile layout and all four navigation destinations render', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith(DemoController.new)],
        child: MaterialApp(
          theme: appTheme,
          home: const RepaintBoundary(
            key: Key('screen'),
            child: CommunityShell(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('服务器状态'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('screen')),
      matchesGoldenFile('goldens/community.png'),
    );
    for (final tab in ['服务器', '聊天', '我的']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('个人资料'), findsOneWidget);
  });
  testWidgets('small mobile viewport accommodates login form', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith(LoggedOutController.new)],
        child: MaterialApp(theme: appTheme, home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('用户名'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class LoggedOutController extends AppController {
  @override
  AppState build() => AppState()..booting = false;
}
