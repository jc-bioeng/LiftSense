import 'package:flutter/material.dart';

class AnalysisScrollController {
  final ScrollController scrollController = ScrollController();
  final ValueNotifier<double> scrollProgress = ValueNotifier(0.0);
  
  double _maxScroll = 0.0;

  void init() {
    scrollController.addListener(_onScroll);
  }

  void updateMaxScroll(double maxScroll) {
    _maxScroll = maxScroll;
  }

  void _onScroll() {
    if (!scrollController.hasClients || _maxScroll <= 0) return;

    final progress = (scrollController.offset / _maxScroll).clamp(0.0, 1.0);
    if (progress != scrollProgress.value) {
      scrollProgress.value = progress;
    }
  }

  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    scrollProgress.dispose();
  }
}
