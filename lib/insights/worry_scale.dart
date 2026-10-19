/// A simple 5-step faces "worry" picture scale, 0 (not worried) to 4 (most
/// worried), asked BEFORE and AFTER play.
///
/// This is a plain ordinal self-report built for the prototype. It is NOT a
/// validated instrument. If the study needs a validated scale, use an
/// established one (for example the Children's Fear Scale, McMurtry et al.,
/// "Children's Fear During Procedural Pain: Preliminary Investigation of the
/// Children's Fear Scale") with the authors' own images and permission, and
/// agree the choice with the supervisors.
const List<String> kWorryLabels = [
  'Not worried',
  'A little worried',
  'Worried',
  'Very worried',
  'The most worried',
];

enum WorryPhase { before, after }

class WorryEntry {
  final DateTime at;
  final WorryPhase phase;
  final int level; // 0..4
  const WorryEntry(this.at, this.phase, this.level);

  Map<String, dynamic> toJson() =>
      {'at': at.toIso8601String(), 'phase': phase.name, 'level': level};

  static WorryEntry? fromJson(dynamic j) {
    if (j is! Map) return null;
    final at = DateTime.tryParse('${j['at']}');
    final level = j['level'];
    if (at == null || level is! num) return null;
    final l = level.toInt();
    if (l < 0 || l > 4) return null;
    WorryPhase? ph;
    for (final p in WorryPhase.values) {
      if (p.name == j['phase']) ph = p;
    }
    if (ph == null) return null;
    return WorryEntry(at, ph, l);
  }
}

/// Pairs every BEFORE with the next AFTER that comes before another BEFORE.
/// Returns after - before for each pair (negative = less worried afterwards).
List<int> worryChanges(Iterable<WorryEntry> entries) {
  final list = entries.toList()..sort((a, b) => a.at.compareTo(b.at));
  final out = <int>[];
  WorryEntry? open;
  for (final e in list) {
    if (e.phase == WorryPhase.before) {
      open = e; // a newer BEFORE replaces an unpaired older one
    } else if (open != null) {
      out.add(e.level - open.level);
      open = null;
    }
  }
  return out;
}

double? meanWorryChange(Iterable<WorryEntry> entries) {
  final c = worryChanges(entries);
  if (c.isEmpty) return null;
  return c.reduce((a, b) => a + b) / c.length;
}
