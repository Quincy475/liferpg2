import 'package:flutter/material.dart';

/// Vaste balk in een scrollende pagina (filterchips).
class PinnedBar extends SliverPersistentHeaderDelegate {
  final double height;
  final Color color;
  final Widget child;
  const PinnedBar({
    required this.height,
    required this.color,
    required this.child,
  });

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
        color: color, alignment: Alignment.centerLeft, child: child);
  }

  @override
  bool shouldRebuild(covariant PinnedBar old) => true;
}
