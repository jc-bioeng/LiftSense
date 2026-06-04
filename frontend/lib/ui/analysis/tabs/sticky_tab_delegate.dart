import 'dart:ui';
import 'package:flutter/material.dart';

class SolidStickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final PreferredSizeWidget child;

  SolidStickyTabBarDelegate(this.child);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            top: -1,
            bottom: -1, 
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF101012).withValues(alpha: 0.85),
                  border: const Border(
                    bottom: BorderSide(
                      color: Color(0x0DFFFFFF),
                      width: 0.5,
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
  double get maxExtent => child.preferredSize.height;

  @override
  double get minExtent => child.preferredSize.height;

  @override
  bool shouldRebuild(covariant SolidStickyTabBarDelegate oldDelegate) =>
      oldDelegate.child != child;
}
