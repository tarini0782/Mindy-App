import '../models/emotion_state.dart';
import 'character_id.dart';

/// Every word a character says lives here, so tone is easy to review.
/// Rules: short, warm, never shaming, never comparing, never a "fail",
/// no clinical or medical claims.
class CharacterLines {
  CharacterLines._();

  static const String mindyGreeting =
      "Hi! I'm Mindy \u2728\nHow are you feeling today?";

  /// Mindy's first line after the child chooses a feeling. Child-friendly
  /// only: it never mentions scores, levels or research.
  static String mindyIntro(EmotionState? e,
      {bool recovery = false, bool afterRegulation = false}) {
    if (afterRegulation) {
      return "That feels a little brighter! Let's keep going gently.";
    }
    if (recovery) return "Let's try something different together.";
    switch (e) {
      case null:
      case EmotionState.scared:
        return "You're safe here. Let's do something gentle together.";
      case EmotionState.sad:
        return "Let's do something gentle together.";
      case EmotionState.neutral:
        return 'Mindy picked an adventure for you!';
      case EmotionState.calm:
        return 'Ready for another adventure?';
      case EmotionState.happy:
        return "You look ready for some fun! Let's go!";
    }
  }

  static const String celebrate = 'Amazing! You completed your adventure!';
  static const String learned = '\u2728 Mindy learned from your play!';
  static const String whatsNext = "Let's see what's next!";
  static const String journeyDone =
      'You finished the whole adventure! Mindy is so proud of you!';

  /// Short line when a session starts (host character).
  static String start(CharacterId id) {
    switch (id) {
      case CharacterId.twinkle:
        return "Let's slow down together.";
      case CharacterId.bubbles:
        return "Help me collect the bubbles!";
      case CharacterId.lumi:
        return 'Look at the magic cards...';
      case CharacterId.nova:
        return 'Time for Power Patterns!';
      case CharacterId.pip:
        return "Let's go exploring!";
      case CharacterId.kara:
        return 'Help me finish the rainbow!';
    }
  }

  static const List<String> bubblesCatch = [
    'Pop pop! Amazing!',
    'Bubbles!',
    'Pop!',
    'Look what we found!',
  ];
  static const List<String> lumiMatch = [
    'You remembered it!',
    'A magical pair!',
    'Lovely!',
  ];
  static const String lumiMiss = "Almost! Let's look again.";
  static const List<String> novaCorrect = [
    'Super pattern!',
    'You found the power!',
    'Your pattern power is growing!',
    'Whoa! Great pattern!',
  ];
  static const String novaTryAgain = "That's okay! Let's try again!";
  static const List<String> karaPlace = [
    'Perfect spot!',
    'The rainbow is coming back!',
    'You did it!',
  ];
  static const String karaTryAgain = 'Almost! Try another spot.';
  static const List<String> pipFind = [
    'You found a treasure!',
    'Sparkly!',
    'Another one!',
  ];

  static const List<String> breatheIn = ['Breathe in...', 'Breathe in...'];
  static const String hold = 'Hold gently...';
  static const String breatheOut = 'Breathe out...';
  static const String breathRest = "You're safe here.";

  static String encourage(CharacterId id) {
    switch (id) {
      case CharacterId.nova:
        return "You're doing great!";
      case CharacterId.lumi:
        return "Let's take our time.";
      case CharacterId.bubbles:
        return "That's okay! Keep going!";
      case CharacterId.pip:
        return "You're doing great!";
      case CharacterId.twinkle:
        return "Let's slow down together.";
      case CharacterId.kara:
        return 'Mindy is proud of your effort!';
    }
  }

  /// Shown on the completion card.
  static String completion(CharacterId id) {
    switch (id) {
      case CharacterId.twinkle:
        return 'The garden is blooming. Well done, friend!';
      case CharacterId.bubbles:
        return 'You helped Bubbles fill the magical bubble basket!';
      case CharacterId.lumi:
        return 'You found every magical pair!';
      case CharacterId.nova:
        return 'Your pattern power is growing!';
      case CharacterId.pip:
        return 'You found another adventure star!';
      case CharacterId.kara:
        return 'The rainbow is complete. Mindy is proud of you!';
    }
  }

  /// Kara reacts to the "how do you feel now?" answer.
  static String moodReaction(EmotionState? before, EmotionState after) {
    if (before == null) return 'Thank you for telling me.';
    if (after.moodScore > before.moodScore) {
      return 'That feels a little brighter!';
    }
    if (after.moodScore == before.moodScore) {
      return 'Thank you for telling me. I am right here.';
    }
    return "I'm right here with you. We can go slowly.";
  }
}
