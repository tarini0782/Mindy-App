/// A repeating list of timed phases (e.g. breathe in / hold / out).
/// Pure Dart, no Flutter -- easy to unit test.
class Phase {
  final String label;
  final double seconds;
  const Phase(this.label, this.seconds);
}

class PhaseTimeline {
  final List<Phase> phases;
  int index = 0;
  double t = 0;

  PhaseTimeline(this.phases);

  Phase get current => phases[index];

  /// 0..1 progress through the current phase.
  double get fraction => (t / current.seconds).clamp(0.0, 1.0).toDouble();

  /// Advances time. Returns true if the phase changed. When the last
  /// phase ends the timeline wraps back to index 0.
  bool tick(double dt) {
    t += dt;
    if (t >= current.seconds) {
      t -= current.seconds;
      index = (index + 1) % phases.length;
      return true;
    }
    return false;
  }
}
