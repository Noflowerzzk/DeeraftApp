import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deeraft/src/motion.dart';
import 'package:deeraft/src/theme.dart';

void main() {
  testWidgets('press feedback preserves the child tap action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressFeedback(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('Press'),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Press')),
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      .975,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });
  testWidgets('reduced motion skips custom page and press animations', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, update) => Scaffold(
              body: Column(
                children: [
                  GestureDetector(
                    onTap: () => update(() => selected = 1),
                    child: const Text('Switch'),
                  ),
                  Expanded(
                    child: MotionPageDeck(
                      index: selected,
                      children: const [
                        Center(child: Text('First')),
                        Center(child: Text('Second')),
                      ],
                    ),
                  ),
                  const PressFeedback(child: SizedBox(width: 50, height: 50)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Switch'));
    await tester.pump();
    expect(find.text('Second'), findsOneWidget);
    final opacity = find
        .descendant(
          of: find.byType(MotionPageDeck),
          matching: find.byType(Opacity),
        )
        .first;
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
      Duration.zero,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('rapid page changes preserve the state of visited pages', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, update) => Scaffold(
            body: Column(
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () => update(() => selected = 0),
                      child: const Text('A'),
                    ),
                    TextButton(
                      onPressed: () => update(() => selected = 1),
                      child: const Text('B'),
                    ),
                  ],
                ),
                Expanded(
                  child: MotionPageDeck(
                    index: selected,
                    children: const [
                      _Counter(),
                      Center(child: Text('Other')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Count 0'));
    await tester.pump();
    await tester.tap(find.text('B'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.text('Count 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact dock supports a narrow screen and larger text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: FloatingDock(index: 0, onChanged: (_) {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => count++),
      child: Text('Count $count'),
    ),
  );
}
