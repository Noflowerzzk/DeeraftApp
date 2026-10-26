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
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.text('主服务器'), findsNothing);
    expect(find.byTooltip('连接设置'), findsNothing);
    expect(find.text('在线玩家'), findsOneWidget);
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
    expect(find.byTooltip('连接设置'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('large player list folds and expands inside MC card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: MinecraftPlayers(
            players: List.generate(12, (i) => 'Player$i'),
            available: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlayerAvatar), findsNWidgets(8));
    await tester.tap(find.text('展开（12）'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerAvatar), findsNWidgets(12));
    await tester.tap(find.text('收起'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerAvatar), findsNWidgets(8));
    expect(tester.takeException(), isNull);
  });
  testWidgets('profile ranks at most five real server records', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith(RankingController.new)],
        child: MaterialApp(theme: appTheme, home: const CommunityShell()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    for (final number in [7, 6, 5, 4, 3]) {
      expect(find.text('World-$number'), findsOneWidget);
    }
    expect(find.text('World-2'), findsNothing);
    expect(find.text('World-1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dark narrow layout supports large text on all destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith(DemoController.new)],
        child: MaterialApp(
          theme: appDarkTheme,
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const CommunityShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final tab in ['服务器', '聊天', '我的', '社区']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });
  testWidgets(
    'profile edit retains inputs after failure and shows saved data',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith(EditController.new)],
          child: MaterialApp(theme: appTheme, home: const CommunityShell()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑资料'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'NewPlayer');
      await tester.enterText(find.byType(TextField).last, '新签名');
      await tester.ensureVisible(find.text('保存修改'));
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();
      expect(find.text('网络连接失败'), findsOneWidget);
      expect(find.text('NewPlayer'), findsOneWidget);
      expect(find.text('新签名'), findsOneWidget);
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();
      expect(find.text('编辑个人资料'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('NewPlayer'), findsOneWidget);
      expect(find.text('新签名'), findsOneWidget);
      // Reopening reads the current profile rather than a stale form snapshot.
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑资料'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'NewPlayer',
      );
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

class LoggedOutController extends AppController {
  @override
  AppState build() => AppState()..booting = false;
}

class EditController extends DemoController {
  bool fail = true;
  @override
  Future<void> updateProfile(String username, String bio) async {
    if (fail) {
      fail = false;
      throw '网络连接失败';
    }
    state = state.clone()..user = UserProfile(username: username, bio: bio);
  }
}

class RankingController extends DemoController {
  @override
  AppState build() => super.build()
    ..playtime = List.generate(
      7,
      (i) => {
        'server_name': 'World-${i + 1}',
        'playtime_minutes': (i + 1) * 61,
      },
    );
}
