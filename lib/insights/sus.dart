/// System Usability Scale (Brooke, 1996). Ten statements answered 1-5.
/// Odd items (positive) score answer-1; even items (negative) score 5-answer;
/// the sum is multiplied by 2.5 to give 0-100. About 68 is the commonly used
/// average benchmark; the proposal sets a target above 68 (Table 6) and 75
/// (Table 9): choose one.
const List<String> kSusStatements = [
  'I think that I would like to use this app frequently.',
  'I found the app unnecessarily complex.',
  'I thought the app was easy to use.',
  'I think that I would need help to be able to use this app.',
  'I found the various functions in this app were well integrated.',
  'I thought there was too much inconsistency in this app.',
  'I would imagine that most people would learn to use this app very quickly.',
  'I found the app very cumbersome to use.',
  'I felt very confident using the app.',
  'I needed to learn a lot of things before I could get going with this app.',
];

/// Returns the 0-100 score, or null if the answers are not ten values 1..5.
double? susScore(List<int> answers) {
  if (answers.length != 10) return null;
  var sum = 0;
  for (var i = 0; i < 10; i++) {
    final a = answers[i];
    if (a < 1 || a > 5) return null;
    sum += i.isEven ? a - 1 : 5 - a;
  }
  return sum * 2.5;
}
