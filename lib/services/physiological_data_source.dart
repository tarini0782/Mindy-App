/// Future extension point for real sensors (heart rate etc.).
///
/// Mindy v1 collects NO physiological data and never fabricates any. The
/// breathing activity does not measure breathing physiology. If a validated
/// sensor is ever added, implement this interface; nothing in the app reads
/// it today.
class PhysiologicalSample {
  final DateTime timestamp;
  final String kind; // e.g. 'heart_rate'
  final double value;
  final String unit;
  const PhysiologicalSample(this.timestamp, this.kind, this.value, this.unit);
}

abstract class PhysiologicalDataSource {
  bool get isAvailable;
  Future<PhysiologicalSample?> latest();
}

/// The only implementation shipped: always "no data".
class NoPhysiologicalDataSource implements PhysiologicalDataSource {
  const NoPhysiologicalDataSource();
  @override
  bool get isAvailable => false;
  @override
  Future<PhysiologicalSample?> latest() async => null;
}
