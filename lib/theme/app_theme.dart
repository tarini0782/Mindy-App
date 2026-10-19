import 'package:flutter/material.dart';

/// Mindy's visual design system. One place for every color, gradient,
/// radius and text style so the whole app feels like it belongs to the
/// same magical world instead of a patchwork of screens.
///
/// Deliberately built with plain Flutter (gradients, shadows, rounded
/// shapes, CustomPainter) rather than external asset packages -- this
/// project has no Rive/Lottie/SVG dependency configured, and adding one
/// mid-project is exactly the kind of change that breaks a build you
/// can't test before a defense. Everything below compiles with nothing
/// but the Flutter SDK.
class AppColors {
  AppColors._();

  // Core palette -- warm, saturated, rounded-corner-friendly.
  static const Color sunshineYellow = Color(0xFFFFC94D);
  static const Color skyBlue = Color(0xFF4FC3F7);
  static const Color deepSky = Color(0xFF0288D1);
  static const Color bubblegumPink = Color(0xFFFF6FA5);
  static const Color grapePurple = Color(0xFF8B5CF6);
  static const Color meadowGreen = Color(0xFF4CD97B);
  static const Color coralOrange = Color(0xFFFF8A65);
  static const Color creamWhite = Color(0xFFFFFBF2);
  static const Color inkNavy = Color(0xFF2B2350);
  static const Color softLavender = Color(0xFFE9E4FF);

  // World-themed gradients, one per mood / one per game world.
  static const List<Color> skyMorning = [Color(0xFFB3E5FC), Color(0xFF64B5F6)];
  static const List<Color> rainCloud = [Color(0xFFB0BEC5), Color(0xFF78909C)];
  static const List<Color> softSun = [Color(0xFFFFE0B2), Color(0xFFFFB74D)];
  static const List<Color> rainbowSky = [
    Color(0xFFFFD1E3),
    Color(0xFFC8B6FF),
    Color(0xFFB6E3FF),
  ];
  static const List<Color> brightSun = [Color(0xFFFFF59D), Color(0xFFFFB300)];

  static const List<Color> bubbleValley = [Color(0xFF80DEEA), Color(0xFF0288D1)];
  static const List<Color> starField = [Color(0xFF9575CD), Color(0xFF4527A0)];
  static const List<Color> calmGarden = [Color(0xFFA5D6A7), Color(0xFF43A047)];
  static const List<Color> memoryForest = [Color(0xFF81C784), Color(0xFF2E7D32)];
  static const List<Color> patternRainbow = [Color(0xFFFFAB91), Color(0xFFEC407A)];
}

class AppRadii {
  AppRadii._();
  static const double sm = 14;
  static const double md = 22;
  static const double lg = 30;
  static const double pill = 999;
}

class AppShadows {
  AppShadows._();
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
  static List<BoxShadow> pressed = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];
}

class AppText {
  AppText._();
  static const String fontFamily = 'Roboto';

  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.inkNavy,
    height: 1.15,
  );
  static const TextStyle subheading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.inkNavy,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.inkNavy,
  );
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );
}

/// Calm palette for the APP shell only (navigation, grown-up screens, the
/// Calm Quest hub). The games keep their own bright colours above; nothing
/// in the games reads these. Chosen to be restful for the eyes without being
/// dull: soft mint backgrounds, a clear teal, periwinkle and warm peach
/// accents. Text/background pairs were checked for contrast (>= 4.5:1 for
/// body text and white-on-teal buttons).
/// v28 "magical adventure" retune. The NAMES are unchanged, so all 28
/// screens pick up the new look without being edited; only the values moved.
///
/// What changed and why: the previous palette was restful but read as
/// clinical on a phone. These are more saturated and warmer while keeping
/// the same job for each token, so the app feels like a storybook rather
/// than a form. Contrast was the constraint, not an afterthought -- every
/// text/background pair below still meets WCAG AA for body text:
///
///   ink (#1F2B5B) on mist (#F6F3FF)      ~ 12.9:1
///   inkSoft (#5A5E8C) on mist            ~  5.6:1
///   white on violet (#6D4BD6)            ~  6.1:1
///   goodInk on goodSoft                  ~  6.4:1
///   attentionInk on attentionSoft        ~  7.3:1
///   considerInk on considerSoft          ~  6.8:1
///
/// If you change any of these, re-check the pair before shipping: a child's
/// app that is pretty and unreadable is worse than a plain one.
/// MINDY — LITTLE EXPLORERS design tokens.
///
/// v29. One place for every colour in the app shell. Screens reference the
/// token NAMES, never raw hex, which is why the whole app re-themes from
/// here without touching 28 screens.
///
/// ---------------------------------------------------------------------
/// CONTRAST IS VERIFIED, NOT ASSUMED.
///
/// The palette this came from (ocean teal #36B8AE, sky #74C8F4, sunny
/// #FFD166, coral #FF896B, meadow #8CCF91, lavender #B8A4F5) was measured
/// against WCAG 2.1. Every one of those six FAILS with white text:
///
///   white on ocean teal   2.43:1   (4.5 needed for body, 3.0 for large)
///   white on sky blue     1.86:1
///   white on sunny yellow 1.44:1
///   white on coral        2.32:1
///   white on meadow       1.83:1
///   white on lavender     2.17:1
///
/// Ocean teal was the proposed PRIMARY, so every primary button would have
/// been unreadable. Deep navy on those same colours passes everything
/// (5.1:1 to 8.6:1).
///
/// So the palette is split by job, keeping the hues:
///   * display   — the original brights, for large fills, game worlds and
///                 illustration. Dark text only.
///   * ink       — darkened to carry WHITE text (buttons, hero gradients).
///   * soft      — ~18% tints over ivory, for surfaces. Dark text only.
///
/// Measured ratios for every pair actually used are in
/// docs/DESIGN_SYSTEM.md. If you change a value, re-measure it.
/// ---------------------------------------------------------------------
class CalmColors {
  CalmColors._();

  // ---- foundation ----------------------------------------------------
  static const Color mist = Color(0xFFFFF9EF); // warm ivory, page background
  static const Color ink = Color(0xFF25354A); // deep navy, body text 11.9:1
  static const Color inkSoft = Color(0xFF5A6B80); // secondary text 5.2:1
  static const Color card = Colors.white;
  static const Color cardBorder = Color(0xFFE8E2D6);

  // ---- display brights: large fills and artwork, DARK TEXT ONLY -------
  static const Color displayTeal = Color(0xFF36B8AE);
  static const Color displaySky = Color(0xFF74C8F4);
  static const Color displaySun = Color(0xFFFFD166);
  static const Color displayCoral = Color(0xFFFF896B);
  static const Color displayMeadow = Color(0xFF8CCF91);
  static const Color displayLavender = Color(0xFFB8A4F5);

  // ---- interactive inks: safe to put WHITE text on -------------------
  static const Color teal = Color(0xFF26837C); // primary, white 4.55:1
  static const Color periwinkle = Color(0xFF0E72A7); // secondary, white 5.27:1
  static const Color danger = Color(0xFFC62D08); // destructive, white 5.56:1

  // ---- soft surfaces: tints over ivory, DARK TEXT ONLY ---------------
  static const Color tealSoft = Color(0xFFDBEDE3); // navy 10.2:1
  static const Color periwinkleSoft = Color(0xFFE6F0F0); // navy 10.7:1
  static const Color peachSoft = Color(0xFFFFE5D7); // navy 10.3:1
  static const Color sunSoft = Color(0xFFFFF2D6); // navy 11.2:1
  static const Color goodSoft = Color(0xFFEAF1DE); // navy 10.8:1
  static const Color lavenderSoft = Color(0xFFF2EAF0); // navy 10.6:1

  // ---- semantic state: each ink measured on its own soft -------------
  static const Color goodInk = Color(0xFF337938); // on goodSoft 4.61:1
  static const Color attentionSoft = sunSoft;
  static const Color attentionInk = Color(0xFF7A4B00); // on sunSoft 6.68:1
  static const Color considerSoft = peachSoft;
  static const Color considerInk = Color(0xFFC62D08); // on peachSoft 4.61:1
  static const Color infoInk = periwinkle; // on periwinkleSoft 4.54:1

  // ---- adventure: forest, parchment and treasure ----------------------
  // The storybook-trail direction. Greens and golds that sit beside the
  // teal tokens above rather than replacing them.
  static const Color forest = Color(0xFF2F6B55); // canopy, walls, woodland
  static const Color forestDeep = Color(0xFF1B3A38); // trunks, shadow
  static const Color meadowLight = Color(0xFFB6D9A4); // open ground
  static const Color parchment = Color(0xFFF4E3BB); // the lit trail, maps
  static const Color parchmentEdge = Color(0xFFCBAE78); // its border
  static const Color treasure = Color(0xFFFFD166); // gold: chests, stars
  static const Color treasureDeep = Color(0xFFF2C14E); // its shaded side

  // ---- dusk: the dark surfaces (sign-in, night scenes) ----------------
  // Every pairing below was measured, not guessed. Ratios are against the
  // surface named in the comment; 4.5:1 is the bar for body text.
  static const Color duskTop = Color(0xFF16302E); // ivory on it 13.40:1
  static const Color duskMid = Color(0xFF1E4440); // ivory on it 10.25:1
  static const Color duskCard = Color(0xFF1F3F3C); // ivory on it 10.93:1
  static const Color duskField = Color(0xFF1A3835); // ivory on it 12.07:1
  static const Color duskInk = mist; // ivory text
  static const Color duskInkSoft = Color(0xFFBFD3CE); // on duskCard 7.32:1
  static const Color duskHint = Color(0xFF93ABA5); // on duskField 5.18:1
  static const Color duskLink = Color(0xFF7FD3C9); // on duskCard 6.58:1
  static const Color duskDanger = Color(0xFFFF9E86); // on duskCard 5.72:1
  static const Color duskFine = Color(0xFF9DB4AE); // on duskMid 4.89:1
  /// Dark text for use ON [treasure]: 8.63:1. Gold needs dark text.
  static const Color onTreasure = ink;
  static const List<Color> dusk = [duskTop, duskMid, Color(0xFF27514C)];

  // ---- kept for existing screens -------------------------------------
  static const Color peach = displayCoral;
  static const Color sun = displaySun;

  /// Headline gradient. Uses the INK variants, not the display brights,
  /// because white headline text sits on it.
  static const List<Color> hero = [teal, periwinkle];
  static const List<Color> heroSoft = [tealSoft, periwinkleSoft];
  static const List<Color> sunrise = [displaySun, displayCoral];
  static const List<Color> meadow = [displayMeadow, displaySky];

  // ---- the three visual modes ----------------------------------------
  // Same tokens throughout; what changes is how much is on screen.
  //   explore  — display brights, full gradients, movement
  //   calm     — ivory and one soft tint, no gradient, minimal movement
  //   research — white cards on ivory, ink and inkSoft only, no decoration
  static const Color calmBackground = mist;
  static const Color calmSurface = tealSoft;
  static const Color researchBackground = mist;
  static const Color researchSurface = Colors.white;
}

/// Builds the app-wide ThemeData (calm palette). Applied once in main.dart.
ThemeData buildMindyTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: CalmColors.teal,
    brightness: Brightness.light,
  ).copyWith(
    primary: CalmColors.teal,
    onPrimary: Colors.white,
    secondary: CalmColors.periwinkle,
    surface: Colors.white,
    onSurface: CalmColors.ink,
    primaryContainer: CalmColors.tealSoft,
    onPrimaryContainer: CalmColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: CalmColors.mist,
    fontFamily: AppText.fontFamily,
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: const BorderSide(color: CalmColors.cardBorder),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CalmColors.teal,
        foregroundColor: Colors.white,
        textStyle: AppText.button,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CalmColors.teal,
        side: const BorderSide(color: CalmColors.teal, width: 1.4),
        textStyle: AppText.button,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: CalmColors.teal),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: CalmColors.tealSoft,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      elevation: 3,
      shadowColor: const Color(0x22000000),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? CalmColors.teal
                : CalmColors.inkSoft,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? CalmColors.teal
                : CalmColors.inkSoft,
          )),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: CalmColors.mist,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: CalmColors.ink,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: AppText.fontFamily,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: CalmColors.ink,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: CalmColors.tealSoft,
      side: BorderSide.none,
      labelStyle: const TextStyle(
          color: CalmColors.ink, fontWeight: FontWeight.w700, fontSize: 12.5),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: CalmColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
