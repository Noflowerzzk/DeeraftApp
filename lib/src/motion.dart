import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 260);
  static const entrance = Duration(milliseconds: 380);
  static const curve = Cubic(.2, .8, .2, 1);
  static Duration duration(BuildContext context, Duration value) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
}

/// Pointer feedback without taking taps or scroll gestures from the child.
class PressFeedback extends StatefulWidget {
  const PressFeedback({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool pressed = false;
  void update(bool value) {
    if (mounted && pressed != value) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled ? (_) => update(true) : null,
    onPointerUp: (_) => update(false),
    onPointerCancel: (_) => update(false),
    child: AnimatedScale(
      scale:
          pressed && widget.enabled && !MediaQuery.disableAnimationsOf(context)
          ? .975
          : 1,
      duration: AppMotion.duration(context, AppMotion.fast),
      curve: AppMotion.curve,
      child: widget.child,
    ),
  );
}

/// Runs once per mounted surface, never on periodic data refreshes.
class MotionReveal extends StatefulWidget {
  const MotionReveal({super.key, required this.child});
  final Widget child;
  @override
  State<MotionReveal> createState() => _MotionRevealState();
}

class _MotionRevealState extends State<MotionReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: AppMotion.entrance,
  );
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = 1;
      started = true;
    } else if (!started) {
      started = true;
      controller.forward();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (context, child) {
      final t = AppMotion.curve.transform(controller.value);
      return Opacity(
        opacity: .55 + .45 * t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      );
    },
  );
}

/// Keeps page state/scroll positions while giving each selection a small entrance.
class MotionPageDeck extends StatefulWidget {
  const MotionPageDeck({
    super.key,
    required this.index,
    required this.children,
  });
  final int index;
  final List<Widget> children;
  @override
  State<MotionPageDeck> createState() => _MotionPageDeckState();
}

class _MotionPageDeckState extends State<MotionPageDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: 1,
  );
  double direction = 1;
  @override
  void didUpdateWidget(MotionPageDeck old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      direction = widget.index > old.index ? 1 : -1;
      if (MediaQuery.disableAnimationsOf(context)) {
        controller.value = 1;
      } else {
        controller.forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) controller.value = 1;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: IndexedStack(
      index: widget.index,
      children: List.generate(
        widget.children.length,
        (i) =>
            TickerMode(enabled: i == widget.index, child: widget.children[i]),
      ),
    ),
    builder: (context, child) {
      final t = AppMotion.curve.transform(controller.value);
      return Opacity(
        opacity: .6 + .4 * t,
        child: Transform.translate(
          offset: Offset(direction * 10 * (1 - t), 0),
          child: child,
        ),
      );
    },
  );
}

class AnimatedMetric extends StatelessWidget {
  const AnimatedMetric(this.value, {super.key, this.style});
  final String value;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.duration(context, AppMotion.standard),
    switchInCurve: AppMotion.curve,
    switchOutCurve: Curves.easeIn,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.centerLeft,
      children: [...previous, ?current],
    ),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: Text(value, key: ValueKey(value), style: style),
  );
}

class FloatingDock extends StatelessWidget {
  const FloatingDock({super.key, required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;
  static const labels = ['社区', '服务器', '聊天', '我的'];
  static const icons = [
    Icons.grid_view_rounded,
    Icons.dns_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.person_outline_rounded,
  ];
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(30, 0, 30, 12),
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(40)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                height: 64,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  color: const Color(0xD9343434),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .14),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth / 4;
                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: AppMotion.duration(
                            context,
                            AppMotion.standard,
                          ),
                          curve: AppMotion.curve,
                          left: index * width,
                          top: 0,
                          bottom: 0,
                          width: width,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(
                            4,
                            (i) => Expanded(
                              child: Semantics(
                                selected: index == i,
                                button: true,
                                child: PressFeedback(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(32),
                                    onTap: () => onChanged(i),
                                    child: SizedBox(
                                      height: 54,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          AnimatedScale(
                                            scale: index == i ? 1.04 : 1,
                                            duration: AppMotion.duration(
                                              context,
                                              AppMotion.fast,
                                            ),
                                            child: Icon(
                                              icons[i],
                                              size: 20,
                                              color: index == i
                                                  ? Colors.white
                                                  : AppColors.muted,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          AnimatedDefaultTextStyle(
                                            duration: AppMotion.duration(
                                              context,
                                              AppMotion.fast,
                                            ),
                                            style: TextStyle(
                                              fontFamily: 'DMSans',
                                              fontFamilyFallback: const [
                                                'NotoSansSC',
                                              ],
                                              fontSize: 10,
                                              fontWeight: index == i
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: index == i
                                                  ? Colors.white
                                                  : AppColors.muted,
                                            ),
                                            child: Text(labels[i]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
