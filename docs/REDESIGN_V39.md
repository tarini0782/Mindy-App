# v39 — One companion, one world: what was done and what was not

Answers the ten deliverables in §15 of the redesign brief, in order.

> **The limitation that shapes everything below.** There is no Flutter or
> Dart SDK in the environment where this was written. **Nothing in v37, v38
> or v39 has been compiled, analysed, tested or built here.** Brief §14
> steps 1–5 and §15 item 8 cannot be answered honestly except by saying
> that. The commands are in §10. The baseline to protect is your last local
> result: `flutter analyze`, 15 info issues, 0 errors.

---

## 1. The new theme and companion concept

**The trail, not the dashboard.** Home is now an illustrated trail with one
stop per journey activity, the child's own friend standing at the stop they
have actually reached, and a treasure chest at the end that opens when the
journey is complete.

The trail is **not decoration**. It has exactly
`AdaptiveGameEngine.journeyLength` stops (6), and the lit ones are
`JourneyController.completedCount`. The brief warned against "decorative
destinations that have no functionality"; stop N is the Nth real activity
of the journey the engine builds. The six names (Welcome Meadow,
Whispering Forest, Puzzle Bridge, Calm Cove, Starry Cave, Treasure
Clearing) are labels over that real progress, and `stopName()` falls back
to a plain number if `journeyLength` ever changes.

Palette is the Little Explorers token set from v36 (warm ivory, teal ink,
soft tints), every pairing contrast-measured — see `DESIGN_SYSTEM.md`.

## 2. Screens redesigned

| Screen | What changed |
| --- | --- |
| **Home** | Rebuilt. See §3 below. |
| **First run** | New `friend_onboarding_screen.dart`. |
| **Journey map** | The Kara mascot that headed the map is now the child's friend, and tapping it opens the one character system instead of the old dress-up screen. |
| **Game transition** | Step 0 (the greeting) is the child's friend. Step 1 keeps the world character, because its text names it. |
| **Every game, all 27** | The in-game speech bubble and the "Taking a break" card now show the child's friend (v38, one change in `game_shell.dart`). |
| **Settings** | The duplicate "Dress up Kara" entry removed. |

### What Home used to be, and what it is now

Before: a rainbow-gradient dashboard — Kara mascot, character strip, two
bright gradient cards, a game carousel, a treasure row, and at the bottom
**a horizontal strip of all six world characters**. That last row was the
clearest statement of the problem the brief describes: six different
characters offered on the one screen meant to introduce the child's own
friend.

Now, in order: the friend greeting the child by name → the trail → the
next stop and progress → one primary action ("Continue my adventure") →
two secondary actions (Calm Corner, My friend) → then the quick-play
carousel and treasures, both **kept**, because §16 forbids removing
working features to simplify the job.

**The six-character row was deleted.** That is a removal, and a deliberate
one: §7 and §16 of the brief both require it.

## 3. Character customisation implemented

- **First-run onboarding** (§11): welcome → choose a starting friend from
  four presets → pick skin, hair and clothing colours → name them → saved.
  Skippable at every step.
- Skipping is **respected, not nagged**: `AvatarService.markOnboardingSeen`
  is stored separately from "has made a character", so a child who skips
  gets the default friend and is never asked again, but can still make one
  from Home at any time.
- The full creator (`character_creator_screen.dart`) is unchanged and still
  reachable from Home, the journey map and settings.
- Options available: 6 skin tones, 6 hair styles, 8 hair colours, 6
  outfits, 6 outfit colours, 6 headwear, 4 wings, 4 faces, 5 extras. No
  option is gendered in its name; nothing is locked, earned or bought.

## 4. How the shared character state works

`AvatarService` is the single source of truth. It is a `ChangeNotifier`
singleton, scoped per child id, persisted in `shared_preferences`, with up
to 6 saved characters and one active.

`active` **never returns null** — a child who has made nothing still has a
default to draw — so no screen has an empty case to handle, and a corrupt
stored entry falls back to the default rather than stopping the app.

Every place the friend appears reads `AvatarService.instance.active` inside
an `AnimatedBuilder` on that service, so changing the look updates every
screen at once. No screen builds its own companion.

### The two competing systems, resolved

The brief (§10, §16) required one system. There were two:

| | `AvatarService` | `CompanionService` |
| --- | --- | --- |
| What it holds | the child's full character | a colour + accessory for Kara |
| Persisted? | yes, per child | **no — in memory only** |
| UI | character creator | "Dress up Kara" screen |

Because `CompanionLook` was never persisted, **there is no saved data to
migrate** — which answers the brief's migration requirement: there is
nothing to migrate. `companion_screen.dart` is now unreferenced anywhere in
`lib/`.

Following §16's "do not silently delete", the file was **left in the repo,
not deleted**, and `CompanionService` still tints the world characters
internally (`character_painter.dart` takes a `CompanionLook`). Removing the
service outright touches `mindy_character.dart` and `character_painter.dart`
and is not worth doing without a compiler. **Your decision**: delete it
after your next green test run, or leave it.

## 5. Changes to the 27 games

**Visual: 2 of 27. Logic: 0 of 27.**

| Game | Change | Logic touched |
| --- | --- | --- |
| Sleepy Fox | Night-meadow backdrop, lit clearing, restyled button (v37) | **none** |
| Calm Maze | Connected lit path on dark woodland, fireflies, lantern glow; plus a real performance fix — the guidance trail ran a full breadth-first search per treasure per frame (v37) | **none** |
| All 27 | In-game speech bubble and break card now show the child's friend (v38) | **none** |

**The other 25 have not been visually themed, and I did not attempt it.**
Rewriting 25 game screens without being able to compile or run one of them
is the single most likely way to break a working project before a panel.
Each game owns its own hit areas, animation timing and event emission;
Sleepy Fox and Sorting Stars carry four of your seven indicators. The two
that were done took real care each, and both are still unverified.

The offer stands: name the next three or four games and they get the same
treatment, one batch at a time, with your analyze/test output between
batches.

## 6. Assets

**None added, none removed, none replaced. There are none.**

An audit of `assets/` found **29 files: 9 `.wav` audio files and 20
`README.txt` placeholders**. All 20 declared asset folders — every
character folder, every world folder — contain only a README. The app has
always been drawn entirely in code (`CustomPainter`) plus emoji.

Two consequences worth stating plainly:

- **I cannot produce illustrations.** Brief §13's "create or obtain
  suitable assets" is beyond what I can do; I can only write vector
  drawing code. Everything added in v37–v39 is code-drawn.
- Brief §12 says "do not use emoji as a substitute for a proper
  illustration system". Many games still use emoji as game pieces. Replacing
  those is an illustration job across 27 games, not a code change, and it
  is not done.

The upside: nothing can fail to load, and nothing has a licensing question.

## 7. Files changed

```
lib/main.dart                              onboarding gate in AuthGate
lib/services/avatar_service.dart           onboardingSeen / needsOnboarding
lib/screens/friend_onboarding_screen.dart  NEW
lib/screens/home_screen.dart               rebuilt as the trail
lib/screens/journey_screen.dart            friend heads the map
lib/screens/settings_screen.dart           duplicate dress-up entry removed
lib/screens/game_transition_screen.dart    greeting is the friend  (v38)
lib/games/base/game_shell.dart             friend speaks in all games (v38)
lib/games/base/game_session_controller.dart  CharacterSay.who nullable (v38)
lib/games/sleepy_fox_game.dart             visual only              (v37)
lib/games/treasure_journey_game.dart       visual + perf fix        (v37)
```

Not touched: the engine, indicators, event schemas, scoring, difficulty
logic, study conditions, or any game's mechanics.

## 8. Analyze, test and build results

**None. Nothing was run.** No Flutter or Dart SDK exists here.

What *was* verified, and the method, so you can judge how much it is worth:

- Every edited file passes a delimiter/string/comment scanner — catches
  unbalanced braces, not type errors.
- Every symbol newly referenced (`CalmColors.*`, `AppRadii.*`, `AppText.*`,
  `AvatarOptions.*`, `RewardService` fields, `JourneyController.completedCount`)
  was confirmed to exist in source.
- `say.who` had exactly one reader before being made nullable; it was
  updated.
- No test in `test/` references `HomeScreen`, `MindyCharacter`,
  `CharacterSay`, `MindyMascot` or `CompanionScreen`, so none should break
  on these changes.

That is static checking. **It is not a compile.**

## 9. Remaining limitations and unfinished work

1. **25 of 27 games are not visually themed** (§5 above).
2. **No illustrated artwork is possible from here** (§6 above).
3. **Feed, Calm Quest, Games and Grownups screens were not restyled.** The
   brief asks for all of them; Home, onboarding, the journey header and the
   transition were done first because that is where the inconsistency was
   worst.
4. **Reduced-motion support is not implemented.** Brief §12 asks for it and
   there is no setting for it yet.
5. **`CompanionService` still exists** internally (§4 above).
6. The trail's avatar placement is arithmetic that has never been rendered.
   It is the single most likely thing to look wrong on a real device, and
   it is a one-number fix when you see it.

## 10. Commands to run locally

```
cd C:\mindy_app
flutter pub get
flutter analyze
flutter test
flutter run
```

Then, on the device: open as a new child (to see first-run onboarding),
make a friend, check Home shows that friend on the trail, start a game and
confirm the friend appears in the speech bubble, pause to see the break
card, and check the journey map header.

Send me the `flutter analyze` output before anything else. The riskiest
edits are the three import changes (`buddy.dart` removed from two screens,
avatar imports added to four) — exactly what analyze catches in seconds.
