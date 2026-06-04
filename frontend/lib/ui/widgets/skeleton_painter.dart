import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

class SkeletonPainterView extends StatefulWidget {
  final String csvPath;
  final int currentPositionMs;
  final bool isActive;
  final Size? videoSize;

  const SkeletonPainterView({
    super.key,
    required this.csvPath,
    required this.currentPositionMs,
    this.isActive = true,
    this.videoSize,
  });

  @override
  State<SkeletonPainterView> createState() => _SkeletonPainterViewState();
}

class _SkeletonPainterViewState extends State<SkeletonPainterView>
    with TickerProviderStateMixin {
  List<(int, List<Offset?>)> _frames = [];
  bool _isLoading = true;
  bool _hasError = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const List<String> nodeNames = [
    'nose', 'l_shoulder', 'r_shoulder', 'l_elbow', 'r_elbow',
    'l_wrist', 'r_wrist', 'l_hip', 'r_hip', 'l_knee', 'r_knee',
    'l_ankle', 'r_ankle', 'l_heel', 'r_heel', 'l_foot_index', 'r_foot_index',
  ];

  static const List<List<int>> connections = [
    [0,1],[0,2],[1,2], [1,3],[3,5], [2,4],[4,6],
    [1,7],[2,8],[7,8], [7,9],[9,11], [8,10],[10,12],
    [11,13],[13,15],[11,15], [12,14],[14,16],[12,16],
  ];

  static const List<int> connectionGroups = [
    0,0,0, 1,1, 1,1, 0,0,0, 2,2, 2,2, 2,2,2, 2,2,2,
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadCsvData();
  }

  @override
  void didUpdateWidget(SkeletonPainterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.csvPath != oldWidget.csvPath) _loadCsvData();
  }

  Future<void> _loadCsvData() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final file = File(widget.csvPath);
      if (!await file.exists()) {
        setState(() { _isLoading = false; _hasError = true; });
        return;
      }
      final lines = await file.readAsLines();
      if (lines.length <= 1) {
        setState(() { _isLoading = false; _hasError = true; });
        return;
      }
      final header = lines.first.split(',');
      final timeMsIdx = header.indexWhere((c) => c.trim() == 'time_ms');
      final Map<String, int> xIdx = {}, yIdx = {}, cIdx = {};
      for (int i = 0; i < header.length; i++) {
        final col = header[i].trim();
        for (final node in nodeNames) {
          if (col == '${node}_x') xIdx[node] = i;
          if (col == '${node}_y') yIdx[node] = i;
          if (col == '${node}_conf') cIdx[node] = i;
        }
      }
      final List<(int, List<Offset?>)> parsed = [];
      for (int i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.length < header.length) continue;
        int timeMs = (double.tryParse(parts[timeMsIdx >= 0 ? timeMsIdx : 0]) ?? 0).round();
        final List<Offset?> pts = List.filled(nodeNames.length, null);
        for (int n = 0; n < nodeNames.length; n++) {
          final node = nodeNames[n];
          final xi = xIdx[node], yi = yIdx[node], ci = cIdx[node];
          if (xi != null && yi != null && ci != null) {
            final x = double.tryParse(parts[xi]) ?? 0;
            final y = double.tryParse(parts[yi]) ?? 0;
            final conf = double.tryParse(parts[ci]) ?? 0;
            if (conf > 0.45) pts[n] = Offset(x, y);
          }
        }
        parsed.add((timeMs, pts));
      }
      if (mounted) setState(() { _frames = parsed; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  int _frameIndexForMs(int posMs) {
    if (_frames.isEmpty) return 0;
    int lo = 0, hi = _frames.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (_frames[mid].$1 < posMs) { lo = mid + 1; } else { hi = mid; }
    }
    return lo;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _hasError || _frames.isEmpty || !widget.isActive) {
      return const SizedBox.shrink();
    }
    final idx = _frameIndexForMs(widget.currentPositionMs);
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _SkeletonFramePainter(
          points: _frames[idx].$2,
          connections: connections,
          connectionGroups: connectionGroups,
          videoSize: widget.videoSize ?? const Size(1080, 1920),
          pulseScale: _pulseAnim.value,
        ),
      ),
    );
  }
}

class _SkeletonFramePainter extends CustomPainter {
  final List<Offset?> points;
  final List<List<int>> connections;
  final List<int> connectionGroups;
  final Size videoSize;
  final double pulseScale;

  _SkeletonFramePainter({
    required this.points,
    required this.connections,
    required this.connectionGroups,
    required this.videoSize,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = max(size.width / videoSize.width, size.height / videoSize.height);
    final dx = (size.width - videoSize.width * scale) / 2;
    final dy = (size.height - videoSize.height * scale) / 2;
    Offset c(Offset r) => Offset(r.dx * scale + dx, r.dy * scale + dy);

    final paint = Paint()..strokeCap = StrokeCap.round;
    for (int i = 0; i < connections.length; i++) {
      final p1 = points[connections[i][0]];
      final p2 = points[connections[i][1]];
      if (p1 == null || p2 == null) continue;
      final cp1 = c(p1), cp2 = c(p2);
      final grp = i < connectionGroups.length ? connectionGroups[i] : 0;
      final color = grp == 0 ? const Color(0xFF00D4AA) : (grp == 1 ? const Color(0xFF4FC3F7) : const Color(0xFFFFB627));
      canvas.drawLine(cp1, cp2, paint..color = color.withValues(alpha: 0.85)..strokeWidth = 3.5);
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonFramePainter old) => true;
}
