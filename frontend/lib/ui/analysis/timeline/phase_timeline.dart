import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/biomech_frame_bus.dart';
import '../../../domain/movement_segment.dart';
import '../coordinator/analysis_playback_controller.dart';
import '../config/biomech_colors.dart';

class RepetitionGroup {
  final int repId;
  final int startMs;
  final int endMs;
  final List<MovementSegment> phases;

  RepetitionGroup(this.repId, this.startMs, this.endMs, this.phases);
}

class PhaseTimeline extends StatefulWidget {
  final BiomechFrameBus bus;
  final AnalysisPlaybackController playback;

  const PhaseTimeline({
    super.key,
    required this.bus,
    required this.playback,
  });

  @override
  State<PhaseTimeline> createState() => _PhaseTimelineState();
}

class _PhaseTimelineState extends State<PhaseTimeline> {
  final ScrollController _scrollController = ScrollController();
  int? _lastActiveRepId;
  
  static const double _itemWidth = 75.0;
  static const double _separatorWidth = 8.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<RepetitionGroup> _groupSegments(List<MovementSegment> segments) {
    final Map<int, List<MovementSegment>> grouped = {};
    for (final seg in segments) {
      if (seg.repId > 0) {
        grouped.putIfAbsent(seg.repId, () => []).add(seg);
      }
    }
    final result = grouped.entries.map((e) {
      final phases = e.value;
      phases.sort((a, b) => a.startMs.compareTo(b.startMs));
      return RepetitionGroup(e.key, phases.first.startMs, phases.last.endMs, phases);
    }).toList();
    result.sort((a, b) => a.repId.compareTo(b.repId));
    return result;
  }

  void _scrollToActiveRep(int index) {
    if (_scrollController.hasClients) {
      final targetOffset = index * (_itemWidth + _separatorWidth);
      
      // Intentar centrar el item en la pantalla
      final screenWidth = MediaQuery.of(context).size.width;
      // Restamos 40 por el padding horizontal de la pantalla en AnalysisScreen
      final availableWidth = screenWidth - 40; 
      final offsetToCenter = targetOffset - (availableWidth / 2) + (_itemWidth / 2);
      
      _scrollController.animateTo(
        offsetToCenter.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.bus.progressNotifier,
      builder: (context, progress, _) {
        return ValueListenableBuilder<int>(
          valueListenable: widget.bus.positionMsNotifier,
          builder: (context, currentMs, _) {
            return ValueListenableBuilder<List<MovementSegment>>(
              valueListenable: widget.bus.segmentsNotifier,
              builder: (context, segments, _) {
                final reps = _groupSegments(segments);
                
                RepetitionGroup? activeRep;
                int activeIndex = -1;
                for (int i = 0; i < reps.length; i++) {
                  final rep = reps[i];
                  if (currentMs >= rep.startMs && currentMs <= rep.endMs) {
                    activeRep = rep;
                    activeIndex = i;
                    break;
                  }
                }
                
                // Trigger auto-scroll si la repetición activa cambió
                if (activeRep != null && activeRep.repId != _lastActiveRepId) {
                  _lastActiveRepId = activeRep.repId;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (activeIndex >= 0) {
                      _scrollToActiveRep(activeIndex);
                    }
                  });
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. REPETITIONS HEADER (Scrollable row of pills)
                    SizedBox(
                      height: 28,
                      child: reps.isNotEmpty 
                        ? ListView.separated(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: reps.length,
                            separatorBuilder: (ctx, idx) => const SizedBox(width: _separatorWidth),
                            itemBuilder: (context, index) {
                              final rep = reps[index];
                              final isActive = rep == activeRep;
                              return GestureDetector(
                                onTap: () => widget.playback.seekTo(Duration(milliseconds: rep.startMs)),
                                child: Container(
                                  width: _itemWidth,
                                  decoration: BoxDecoration(
                                    color: isActive ? BiomechColors.optimal : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isActive ? BiomechColors.optimal : Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'REP ${rep.repId}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                                      color: isActive ? Colors.white : Colors.white54,
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                              'ANALIZANDO REPETICIONES...',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white30,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 2. DYNAMIC PHASE STEPPER
                    Builder(builder: (context) {
                      final currentRep = activeRep;
                      return SizedBox(
                        height: 24,
                        child: currentRep != null ? Center(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: currentRep.phases.asMap().entries.map((entry) {
                                final phase = entry.value;
                                final isLast = entry.key == currentRep.phases.length - 1;
                                final isPhaseActive = currentMs >= phase.startMs && currentMs <= phase.endMs;
                                
                                return Row(
                                  children: [
                                    Text(
                                      phase.displayLabel.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: isPhaseActive ? 12 : 10,
                                        fontWeight: isPhaseActive ? FontWeight.w800 : FontWeight.w500,
                                        color: isPhaseActive ? phase.displayColor : Colors.white30,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    if (!isLast)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: Icon(Icons.arrow_forward_ios, size: 8, color: Colors.white24),
                                      ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ) : Center(
                          child: Text(
                            'IDLE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white30,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    
                    // 3. GLOBAL MINIMAP SCRUBBER
                    LayoutBuilder(
                      builder: (context, constraints) {
                        void handleScrub(double localX) {
                          widget.playback.pause();
                          final totalMs = widget.bus.totalDurationMs;
                          if (totalMs > 0) {
                            final fraction = (localX / constraints.maxWidth).clamp(0.0, 1.0);
                            final targetMs = (fraction * totalMs).toInt();
                            widget.playback.seekTo(Duration(milliseconds: targetMs));
                          }
                        }

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) => handleScrub(details.localPosition.dx),
                          onHorizontalDragStart: (details) => handleScrub(details.localPosition.dx),
                          onHorizontalDragUpdate: (details) => handleScrub(details.localPosition.dx),
                          child: Container(
                            height: 28, // Ampliado para mejorar ergonomía táctil
                            alignment: Alignment.center,
                            child: Container(
                              height: 16,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: const Color(0xFF141416),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Stack(
                                children: [
                                  Row(
                                    children: segments.asMap().entries.map((entry) {
                                      final seg = entry.value;
                                      final isLast = entry.key == segments.length - 1;
                                      final totalMs = widget.bus.totalDurationMs;
                                      final flex = totalMs > 0
                                          ? ((seg.endPercent(totalMs) - seg.startPercent(totalMs)) * 1000).toInt()
                                          : 1;
                                      return Expanded(
                                        flex: flex.clamp(1, 1000),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: seg.displayColor.withValues(alpha: 0.6),
                                            border: isLast ? null : const Border(
                                              right: BorderSide(color: Colors.black45, width: 1.0),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  Positioned.fill(
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          left: (constraints.maxWidth * progress - 3).clamp(0.0, constraints.maxWidth),
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 6,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(3),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.white.withValues(alpha: 0.8),
                                                  blurRadius: 6,
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
