import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'theme.dart';

/// Two resting positions for the status header, then ordinary list scrolling.
/// A ballistic simulation remains interruptible by a new finger gesture.
class CommunitySnapPhysics extends ScrollPhysics {
  const CommunitySnapPhysics({
    required this.snapExtent,
    this.reduceMotion = false,
    super.parent,
  });
  final double snapExtent;
  final bool reduceMotion;

  @override
  CommunitySnapPhysics applyTo(ScrollPhysics? ancestor) => CommunitySnapPhysics(
    snapExtent: snapExtent,
    reduceMotion: reduceMotion,
    parent: buildParent(ancestor),
  );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange ||
        snapExtent <= 0 ||
        position.pixels <= 0 ||
        position.pixels >= snapExtent ||
        velocity.abs() > 1400) {
      return super.createBallisticSimulation(position, velocity);
    }
    final end = snapExtent.clamp(0.0, position.maxScrollExtent);
    final target = velocity > 220
        ? end
        : velocity < -220
        ? 0.0
        : position.pixels < end / 2
        ? 0.0
        : end;
    if (reduceMotion) return _ImmediateSnap(target);
    return ScrollSpringSimulation(
      const SpringDescription(mass: 1, stiffness: 250, damping: 30),
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}

class _ImmediateSnap extends Simulation {
  _ImmediateSnap(this.target);
  final double target;
  @override
  double x(double time) => target;
  @override
  double dx(double time) => 0;
  @override
  bool isDone(double time) => true;
}

/// A shared layout for expanded, intermediate and compact status states.
/// The light sheet lip belongs to the pinned header so its radius stays fixed.
class CommunityStatusHeader extends SliverPersistentHeaderDelegate {
  CommunityStatusHeader({
    required this.community,
    required this.expandedExtent,
    required this.collapsedExtent,
    required this.sheetColor,
  });
  final CommunityStatus? community;
  final double expandedExtent, collapsedExtent;
  final Color sheetColor;
  static const sheetRadius = 32.0;
  @override
  double get maxExtent => expandedExtent;
  @override
  double get minExtent => collapsedExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final h = appDarkTheme.colorScheme;
    final t = Theme.of(context).textTheme;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final detailOpacity = (1 - progress / .65).clamp(0.0, 1.0);
    final mc = community?.mc ?? <String, dynamic>{};
    final available = community?.mcSource.available ?? false;
    final status = !available
        ? '状态未知'
        : mc['online'] == true
        ? '在线'
        : '离线';
    final statusColor = !available
        ? h.tertiary
        : mc['online'] == true
        ? h.primary
        : h.error;
    final motd = available
        ? cleanMotd(mc['motd']?.toString() ?? '')
        : (community?.mcSource.error ?? '等待服务器状态');
    return ColoredBox(
      color: h.surface,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 24,
              right: 24,
              top: 16 - progress * 18,
              child: ExcludeSemantics(
                excluding: detailOpacity < .1,
                child: Opacity(
                  opacity: detailOpacity,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '服务器状态',
                          style: t.labelLarge?.copyWith(
                            color: h.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        community == null
                            ? '正在加载…'
                            : '${DateFormat('HH:mm').format(community!.fetchedAt.toLocal())} 更新',
                        style: t.labelMedium?.copyWith(
                          color: h.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 122,
              top: lerpDouble(54, 12, progress),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Minecraft',
                  key: const Key('community-world-title'),
                  style: t.titleLarge?.copyWith(
                    fontSize: lerpDouble(24, 18, progress),
                    color: h.onSurface,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 24,
              top: lerpDouble(58, 14, progress),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: t.labelLarge?.copyWith(color: statusColor),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: lerpDouble(98, 40, progress),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      available ? '${mc['online_count'] ?? 0}' : '—',
                      key: const Key('community-online-count'),
                      style: t.displayLarge?.copyWith(
                        fontSize: lerpDouble(88, 28, progress),
                        height: 1.12,
                        color: h.primary,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '在线',
                      style: t.titleMedium?.copyWith(color: h.onSurface),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: 98 + 96 * scale + 20 - progress * 42,
              child: IgnorePointer(
                ignoring: detailOpacity < .1,
                child: ExcludeSemantics(
                  excluding: detailOpacity < .1,
                  child: Opacity(
                    opacity: detailOpacity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tooltip(
                          message: motd,
                          child: Text(
                            motd,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyLarge?.copyWith(color: h.onSurface),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 20,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              mc['version']?.toString() ?? 'Java Edition',
                              style: t.bodyMedium?.copyWith(
                                color: h.onSurfaceVariant,
                              ),
                            ),
                            if (available)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.network_check,
                                    size: 18,
                                    color: h.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${(mc['latency_ms'] as num?)?.round() ?? '—'} ms',
                                    style: t.bodyMedium?.copyWith(
                                      color: h.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: sheetRadius,
              child: DecoratedBox(
                key: const Key('community-sheet-lip'),
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(sheetRadius),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(CommunityStatusHeader oldDelegate) =>
      community != oldDelegate.community ||
      sheetColor != oldDelegate.sheetColor ||
      maxExtent != oldDelegate.maxExtent ||
      minExtent != oldDelegate.minExtent;
}
