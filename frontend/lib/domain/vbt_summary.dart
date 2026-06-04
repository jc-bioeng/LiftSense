class VbtSummary {
  final List<double> repMeanVelocities;
  final List<double> repPeakVelocities;
  final double meanVelocity;
  final double peakVelocity;
  final double velocityLossPercent;
  final int repCount;

  const VbtSummary({
    required this.repMeanVelocities,
    required this.repPeakVelocities,
    required this.meanVelocity,
    required this.peakVelocity,
    required this.velocityLossPercent,
    required this.repCount,
  });

  static const empty = VbtSummary(
    repMeanVelocities: [],
    repPeakVelocities: [],
    meanVelocity: 0.0,
    peakVelocity: 0.0,
    velocityLossPercent: 0.0,
    repCount: 0,
  );

  bool get isEmpty => repCount == 0;
}
