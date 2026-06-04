import 'package:flutter/material.dart';
import 'timeline_data.dart';
import 'timeline_layers.dart';

class BiomechTimeline extends StatefulWidget {
  final List<TimelineDataPoint> rawData;
  final List<BiomechEvent> rawEvents;
  final int totalDurationMs;
  final int currentTimeMs;
  final Function(int) onSeek; // Callback para el scrubber

  const BiomechTimeline({
    Key? key,
    required this.rawData,
    required this.rawEvents,
    required this.totalDurationMs,
    required this.currentTimeMs,
    required this.onSeek,
  }) : super(key: key);

  @override
  State<BiomechTimeline> createState() => _BiomechTimelineState();
}

class _BiomechTimelineState extends State<BiomechTimeline> {
  bool _showDepth = true; // Toggle: true = Depth, false = Velocity
  bool _isScrubbing = false;
  double _zoomScale = 1.0;
  
  late List<TimelineDataPoint> _optimizedData;
  late List<TimelineCluster> _clusters;

  @override
  void initState() {
    super.initState();
    _processData();
  }

  void _processData() {
    // 1. Biomechanical-aware Decimation
    _optimizedData = TimelineDataProcessor.optimizePoints(widget.rawData, 0.05);
    // 2. Event Clustering
    _clusters = TimelineDataProcessor.clusterEvents(widget.rawEvents, 200); // 200ms tolerancia
  }

  void _handlePan(DragUpdateDetails details, double maxWidth) {
    setState(() => _isScrubbing = true);
    double renderWidth = maxWidth * _zoomScale;
    double fraction = details.localPosition.dx / renderWidth;
    int targetMs = (fraction * widget.totalDurationMs).clamp(0, widget.totalDurationMs).toInt();
    widget.onSeek(targetMs);
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() => _isScrubbing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      color: const Color(0xFF0D0D12), // Fondo técnico
      child: Column(
        children: [
          // 1. HUD Toggle (Depth | Velocity)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                _buildToggle('DEPTH', true),
                const SizedBox(width: 12),
                _buildToggle('VELOCITY', false),
              ],
            ),
          ),
          
          // 2. Timeline Layers (4-Layer Architecture)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onPanUpdate: (d) => _handlePan(d, constraints.maxWidth),
                  onPanEnd: _handlePanEnd,
                  onTapDown: (d) {
                     setState(() => _isScrubbing = true);
                     double fraction = d.localPosition.dx / (constraints.maxWidth * _zoomScale);
                     widget.onSeek((fraction * widget.totalDurationMs).toInt());
                     setState(() => _isScrubbing = false);
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // LAYER 1: Background estático
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: TimelineBackgroundPainter(_optimizedData, widget.totalDurationMs, zoomScale: _zoomScale),
                        ),
                      ),
                      // LAYER 2: Gráfica Pre-computada
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: TimelineGraphPainter(_optimizedData, widget.totalDurationMs, _showDepth, zoomScale: _zoomScale),
                        ),
                      ),
                      // LAYER 3: Marcadores Clustereados
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: TimelineMarkersPainter(_clusters, widget.totalDurationMs, zoomScale: _zoomScale),
                        ),
                      ),
                      // LAYER 4: Realtime Playhead (Ultra ligero)
                      CustomPaint(
                        painter: TimelinePlayheadPainter(widget.currentTimeMs, widget.totalDurationMs, _isScrubbing, zoomScale: _zoomScale),
                      ),
                    ],
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String title, bool isDepth) {
    bool isSelected = _showDepth == isDepth;
    return GestureDetector(
      onTap: () => setState(() => _showDepth = isDepth),
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.cyanAccent : Colors.white54,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'RobotoMono',
          fontSize: 12,
        ),
      ),
    );
  }
}
