import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 260);
  static const entrance = Duration(milliseconds: 380);
  static const curve = Cubic(.2, 0, 0, 1);
  static Duration duration(BuildContext context, Duration value) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
}

/// A zero-duration AnimatedSize can relayout itself inside a sliver layout.
/// Skip the render animation entirely when the system removes animations.
class MotionSize extends StatelessWidget {
  const MotionSize({
    super.key,
    required this.child,
    this.duration = AppMotion.standard,
    this.curve = AppMotion.curve,
    this.alignment = Alignment.topCenter,
  });
  final Widget child;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;
  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(
          duration: duration,
          curve: curve,
          alignment: alignment,
          child: child,
        );
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

// Material's native destination indicator, ripple and label transitions.
class FloatingDock extends StatelessWidget {
  const FloatingDock({super.key, required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;
  static const labels = ['社区', '服务器', '聊天', '我的'];
  static const icons = [
    Icons.people_outline,
    Icons.dns_outlined,
    Icons.chat_bubble_outline,
    Icons.person_outline,
  ];
  static const selectedIcons = [
    Icons.people,
    Icons.dns,
    Icons.chat_bubble,
    Icons.person,
  ];
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: index,
    onDestinationSelected: onChanged,
    animationDuration: AppMotion.duration(context, AppMotion.standard),
    destinations: List.generate(
      4,
      (i) => NavigationDestination(
        icon: Icon(icons[i]),
        selectedIcon: Icon(selectedIcons[i]),
        label: labels[i],
      ),
    ),
  );
}
