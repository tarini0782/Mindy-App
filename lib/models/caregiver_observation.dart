/// Caregiver-reported observation ("What have you noticed recently?").
/// Always labelled as caregiver-reported. It is never treated as objective
/// sensor data and never feeds the adaptive engine.
enum ObservationType {
  comfortable,
  worried,
  sad,
  withdrawn,
  communicative,
  unchanged,
  other,
}

extension ObservationTypeX on ObservationType {
  String get label {
    switch (this) {
      case ObservationType.comfortable:
        return 'Child seems comfortable';
      case ObservationType.worried:
        return 'Child seems worried';
      case ObservationType.sad:
        return 'Child seems sad';
      case ObservationType.withdrawn:
        return 'Child seems more withdrawn';
      case ObservationType.communicative:
        return 'Child seems more communicative';
      case ObservationType.unchanged:
        return "Child's behaviour seems unchanged";
      case ObservationType.other:
        return 'Other';
    }
  }
}

class CaregiverObservation {
  final String id;
  final DateTime timestamp;
  final ObservationType type;
  final String note; // optional free text (may be empty)

  const CaregiverObservation({
    required this.id,
    required this.timestamp,
    required this.type,
    this.note = '',
  });

  /// v48: was 'Caregiver-reported observation'. Same meaning, without the
  /// questionnaire register — this chip sits on a screen a parent reads.
  static const String sourceLabel = 'Your note';

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'note': note,
        'source': 'caregiver_reported',
      };

  factory CaregiverObservation.fromJson(Map<String, dynamic> j) {
    var type = ObservationType.other;
    for (final t in ObservationType.values) {
      if (t.name == j['type']) type = t;
    }
    return CaregiverObservation(
      id: (j['id'] as String?) ?? '',
      timestamp: DateTime.tryParse((j['timestamp'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      type: type,
      note: (j['note'] as String?) ?? '',
    );
  }
}
