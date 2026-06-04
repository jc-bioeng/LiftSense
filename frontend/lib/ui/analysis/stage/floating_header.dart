import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../coordinator/analysis_scroll_controller.dart';

class FloatingHeader extends StatelessWidget {
  final AnalysisScrollController scroll;
  final String exerciseName;
  final String viewTag;
  final String captureDate;

  const FloatingHeader({
    super.key,
    required this.scroll,
    required this.exerciseName,
    required this.viewTag,
    required this.captureDate,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: scroll.scrollProgress,
      builder: (context, progress, _) {
        final topPadding = MediaQuery.of(context).padding.top;
        final blurSigma = 20.0 * progress;
        final bgOpacity = 0.75 * progress;

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma.clamp(0.01, 25.0),
                sigmaY: blurSigma.clamp(0.01, 25.0),
              ),
              child: Container(
                padding: EdgeInsets.fromLTRB(12, topPadding + 8, 20, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E).withValues(alpha: bgOpacity),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15 * progress),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 14),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.0,
                          fontSize: 16,
                        ),
                        children: [
                          TextSpan(
                            text: 'LIFT',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                          ),
                          const TextSpan(
                            text: 'SENSE',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          exerciseName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                viewTag,
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              captureDate,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white38,
                                fontWeight: FontWeight.w500,
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
        );
      },
    );
  }
}
