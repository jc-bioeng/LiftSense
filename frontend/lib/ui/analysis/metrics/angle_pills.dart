import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/biomech_frame_bus.dart';
import '../../../services/biomech_selectors.dart';
import '../config/biomech_colors.dart';
import '../models/ui/angle_pill_ui_model.dart';

class AnglePills extends StatefulWidget {
  final BiomechFrameBus bus;

  const AnglePills({super.key, required this.bus});

  @override
  State<AnglePills> createState() => _AnglePillsState();
}

class _AnglePillsState extends State<AnglePills> {
  late final MemoizedAngleSelector _hipSelector;
  late final MemoizedAngleSelector _kneeSelector;
  late final MemoizedAngleSelector _ankleSelector;
  late final MemoizedAngleSelector _trunkSelector;

  @override
  void initState() {
    super.initState();
    _hipSelector = BiomechSelectors.createHipFlexion();
    _kneeSelector = BiomechSelectors.createKneeFlexion();
    _ankleSelector = BiomechSelectors.createAnkleFlexion();
    _trunkSelector = BiomechSelectors.createTrunkFlexion();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÁNGULOS EN TIEMPO REAL',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: BiomechColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ReactivePill(bus: widget.bus, selector: _hipSelector)),
            const SizedBox(width: 8),
            Expanded(child: _ReactivePill(bus: widget.bus, selector: _kneeSelector)),
            const SizedBox(width: 8),
            Expanded(child: _ReactivePill(bus: widget.bus, selector: _ankleSelector)),
            const SizedBox(width: 8),
            Expanded(child: _ReactivePill(bus: widget.bus, selector: _trunkSelector)),
          ],
        ),
      ],
    );
  }
}

class _ReactivePill extends StatefulWidget {
  final BiomechFrameBus bus;
  final MemoizedAngleSelector selector;

  const _ReactivePill({
    required this.bus,
    required this.selector,
  });

  @override
  State<_ReactivePill> createState() => _ReactivePillState();
}

class _ReactivePillState extends State<_ReactivePill> {
  late AnglePillUiModel _model;

  @override
  void initState() {
    super.initState();
    _model = widget.selector.select(widget.bus.frameNotifier.value);
    widget.bus.frameNotifier.addListener(_onFrame);
  }

  @override
  void dispose() {
    widget.bus.frameNotifier.removeListener(_onFrame);
    super.dispose();
  }

  void _onFrame() {
    final newModel = widget.selector.select(widget.bus.frameNotifier.value);
    if (!identical(newModel, _model)) {
      setState(() {
        _model = newModel;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: BiomechColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          top: BorderSide(color: _model.accentColor, width: 2.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _model.label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: BiomechColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _model.formattedValue,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: BiomechColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _model.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _model.statusLabel,
              style: GoogleFonts.inter(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: _model.accentColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
