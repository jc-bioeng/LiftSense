import 'dart:ui';
import 'package:flutter/material.dart';

class SolidStickyTimelineDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  SolidStickyTimelineDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Stack(
        children: [
          Positioned.fill(
            top: -2,
            bottom: -2,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xD9101012),
                ),
              ),
            ),
          ),
          // Subtle top border overlay to make the rounded edges stand out
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SolidStickyTimelineDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
