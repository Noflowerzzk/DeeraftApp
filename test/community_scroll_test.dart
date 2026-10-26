import 'package:deeraft/src/community_scroll.dart';
import 'package:deeraft/src/screens.dart';
import 'package:deeraft/src/theme.dart';
import 'package:deeraft/src/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens_test.dart' show DemoController;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'NotoSansSC',
    )..addFont(rootBundle.load('assets/fonts/NotoSansSC.ttf'))).load();
  });
  ScrollMetrics metrics(double pixels) => FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: 900,
    pixels: pixels,
    viewportDimension: 640,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 1,
  );
  const physics = CommunitySnapPhysics(
    snapExtent: 280,
    parent: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
  );

  test('release uses nearest anchor or deliberate fling direction', () {
    expect(
      physics.createBallisticSimulation(metrics(70), 0)!.x(4),
      closeTo(0, .1),
    );
    expect(
      physics.createBallisticSimulation(metrics(200), 0)!.x(4),
      closeTo(280, .1),
    );
    expect(
      physics.createBallisticSimulation(metrics(70), 350)!.x(4),
      closeTo(280, .1),
    );
    expect(
      physics.createBallisticSimulation(metrics(200), -350)!.x(4),
      closeTo(0, .1),
    );
  });
  test(
    'list scrolling and boundary rebound do not snap back to the header',
    () {
      expect(physics.createBallisticSimulation(metrics(420), 0), isNull);
      expect(
        physics.createBallisticSimulation(metrics(-30), 0)!.x(4),
        closeTo(0, .1),
      );
      expect(
        physics.createBallisticSimulation(metrics(940), 0)!.x(4),
        closeTo(900, .1),
      );
      expect(
        physics.createBallisticSimulation(metrics(100), 1800)!.x(.2),
        greaterThan(280),
      );
    },
  );
  test('reduced motion resolves snap without an animated spring', () {
    const reduced = CommunitySnapPhysics(snapExtent: 280, reduceMotion: true);
    final simulation = reduced.createBallisticSimulation(metrics(200), 0)!;
    expect(simulation.x(0), 280);
    expect(simulation.dx(0), 0);
    expect(simulation.isDone(0), isTrue);
  });

  Future<void> mount(
    WidgetTester tester, {
    AppController Function()? factory,
    bool reduce = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith(factory ?? DemoController.new)],
        child: MaterialApp(
          theme: appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduce,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: const CommunityShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder scrollView() => find.descendant(
    of: find.byType(CommunityScreen),
    matching: find.byType(CustomScrollView),
  );
  ScrollController controller(WidgetTester tester) =>
      tester.widget<CustomScrollView>(scrollView()).controller!;
  double snapExtent(WidgetTester tester) =>
      (tester.widget<CustomScrollView>(scrollView()).physics!
              as CommunitySnapPhysics)
          .snapExtent;

  testWidgets(
    'one header continuously rearranges while the sheet keeps its corner radius',
    (tester) async {
      await mount(tester);
      final scroll = controller(tester), end = snapExtent(tester);
      final initialTop = tester
          .getTopLeft(find.byKey(const Key('community-sheet-lip')))
          .dy;
      scroll.jumpTo(end * .4);
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('community-online-count')))
            .style!
            .fontSize,
        closeTo(64, .1),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('community-sheet-lip'))).dy,
        closeTo(initialTop - end * .4, .1),
      );
      final before =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const Key('community-sheet-lip')),
                  )
                  .decoration
              as BoxDecoration;
      scroll.jumpTo(end);
      await tester.pumpAndSettle();
      final after =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const Key('community-sheet-lip')),
                  )
                  .decoration
              as BoxDecoration;
      expect(after.borderRadius, before.borderRadius);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('community-online-count')))
            .style!
            .fontSize,
        28,
      );
      expect(find.byKey(const Key('community-world-title')), findsOneWidget);
      await tester.tap(find.text('聊天').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('社区').last);
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(end, .1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('finger release snaps and a new drag can interrupt the spring', (
    tester,
  ) async {
    await mount(tester);
    final scroll = controller(tester), end = snapExtent(tester);
    final gesture = await tester.startGesture(const Offset(200, 550));
    await gesture.moveBy(const Offset(0, -210));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(end, .5));
    scroll.jumpTo(end * .7);
    await tester.pump(const Duration(milliseconds: 40));
    final interrupt = await tester.startGesture(const Offset(200, 450));
    await interrupt.moveBy(const Offset(0, 200));
    await tester.pump(const Duration(milliseconds: 300));
    await interrupt.up();
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(0, .5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'player filter stays whole after further scrolling and names respond to taps',
    (tester) async {
      await mount(tester);
      final scroll = controller(tester), end = snapExtent(tester);
      scroll.jumpTo(end);
      await tester.pumpAndSettle();
      final controls = find.byKey(const Key('community-player-controls'));
      final top = tester.getTopLeft(controls).dy;
      scroll.jumpTo(end + 30);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(controls).dy, closeTo(top, .1));
      final bounds = tester.getRect(controls);
      expect(
        tester.getTopLeft(find.text('在线玩家')).dy,
        greaterThanOrEqualTo(bounds.top),
      );
      expect(
        tester.getBottomLeft(find.text('全部')).dy,
        lessThanOrEqualTo(bounds.bottom),
      );
      await tester.tap(find.text('AInfinity_Dream').first);
      await tester.pumpAndSettle();
      expect(
        find.text('AInfinity_Dream', findRichText: true),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pull refresh returns to the top and preserves the sheet geometry',
    (tester) async {
      final app = RefreshController();
      await mount(tester, factory: () => app);
      final top = tester
          .getTopLeft(find.byKey(const Key('community-sheet-lip')))
          .dy;
      await tester.drag(scrollView(), const Offset(0, 280));
      await tester.pumpAndSettle();
      expect(app.refreshes, 1);
      expect(controller(tester).offset, closeTo(0, .5));
      expect(
        tester.getTopLeft(find.byKey(const Key('community-sheet-lip'))).dy,
        closeTo(top, .5),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'large text and reduced motion keep compact status and snapping usable',
    (tester) async {
      await mount(tester, reduce: true, scale: 2);
      final scroll = controller(tester), end = snapExtent(tester);
      scroll.jumpTo(end * .7);
      await tester.pump();
      await tester.pump();
      expect(scroll.offset, closeTo(end, .5));
      expect(
        tester
            .widget<Text>(find.byKey(const Key('community-online-count')))
            .style!
            .fontSize,
        28,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class RefreshController extends DemoController {
  int refreshes = 0;
  @override
  Future<void> refresh() async {
    refreshes++;
  }
}
