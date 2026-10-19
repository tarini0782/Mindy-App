# Mindy v6 -- the magical world & its six friends

> **Read first.** I wrote this without a Flutter SDK, so it has **not been
> compiled or run**. Run `flutter analyze` and `flutter test`, and send me the
> exact red text if anything fails; expect a few small fixes. I did check
> bracket balance, every import path, map reachability and the engine/test
> logic by hand.

## Setup (Windows, project at C:\mindy_app)
1. Stop the running app (`q` + Enter in the flutter terminal).
2. In `C:\mindy_app`, delete the old `lib` and `test` folders and the old
   `assets` folder.
3. Copy from this zip: `lib/`, `test/`, `assets/`.
4. Open `pubspec.yaml` and add the asset folders from `PUBSPEC_ASSETS.txt`.
5. Run:
   ```
   flutter pub get
   flutter analyze
   flutter test
   flutter run
   ```
`docs/history/` holds the old v3/v4/v5 notes. You can delete it.

## The cast (all original; vector-drawn in code, no external art needed)
| Character | Who | Lives in | Role |
|---|---|---|---|
| Kara | magical rainbow unicorn | Rainbow Kingdom + the check-in, transitions, mood replies | welcomes, guides, reacts to feelings |
| Twinkle | tiny fairy | Magic Garden | guides breathing |
| Bubbles | cute bunny | Bubble Valley | catches bubbles, jumps for joy |
| Lumi | kind princess | Memory Castle | memory and magic cards |
| Nova | small hero (cape + mask) | Superhero Academy | pattern power, cheers you on |
| Pip | baby dragon | Dragon Valley | explores, collects treasure |

Each has six animation states: idle, happy, excited, calm, encouraging,
celebrating (`lib/characters/`). Kara can be dressed up (Settings or tap Kara
on the map): 4 colours, 5 extras, free, no purchases.

## The six worlds (5 levels each)
| World | Character | Game | Mechanic | What levels 1 -> 5 change |
|---|---|---|---|---|
| Magic Garden | Twinkle | Breathing Garden | breathing | 3,3,4,5,6 breaths; longer holds/exhales; more stars, sparkles, butterflies; sparkle taps at L4-5. No score, no fail |
| Bubble Valley | Bubbles | Bubble Adventure | tap / catch | bubble size 50->28, speed 26->60, 2->6 at once, 6->14 catches, sleepy-cloud distractors at L4-5, wavier drift at L5. No timer |
| Memory Castle | Lumi | Magic Memory | memory match | 3,4,5,6,8 pairs; preview 3.2s->1.8s; grid 3x2 -> 4x4; decorative sparkles at L5 |
| Superhero Academy | Nova | Pattern Power | pattern completion | AB, AAB, ABC, ABBC, ABCCB; 2->5 choices; 3->6 rounds; hidden symbol moves round to round |
| Rainbow Kingdom | Kara | Rainbow Puzzle | drag / arrange | 3,4,5,6,8 pieces; L4 twin clouds; L5 look-alike pieces (flower/blossom, star/glow star) |
| Dragon Valley | Pip | Treasure Journey | exploration | 5 hand-made maps, bigger and branchier; guiding trail on L1-2, hints on L3, none on L4-5. No enemies, no timer |

## How the adaptive engine now works (`games/engine/adaptive_game_engine.dart`)
| Feeling | Base level | Pace | Worlds it can pick (rotating) |
|---|---|---|---|
| scared / skipped | 1 | slow | Magic Garden |
| sad | 1 | slow | Magic Garden, Bubble Valley |
| neutral | 3 | normal | Memory Castle, Pattern Power, Rainbow Puzzle |
| calm | 4 | normal | Pattern Power, Dragon Valley, Rainbow Puzzle |
| happy | 4 | normal | Pattern Power, Dragon Valley |

* Matches your proposal's Appendix C tiers (scared/sad easy, neutral medium, calm/happy hard).
* Performance nudge: at most one level, from the last session's accuracy, never for scared/sad, never after a game with no right/wrong moments (breathing, exploration). That is why levels 2 and 5 appear only through a nudge or the bridge step.
* **Bridge step:** after a finished Magic Garden session that ends in a better mood, the next pick is Bubble Valley at level 1-2 (the "sad -> garden -> bubbles" story from your brief).
* The fixed/control condition (Settings) still ignores emotion entirely.
* Every decision keeps its technical `reason` string (the DecisionTrace) -- children only see Kara's friendly lines.

## The flow a child sees
Kara asks how you feel -> Kara answers ("Hey... let's take a gentle moment together.") -> the world's character invites you ("Come with me to the magical garden.") -> play, with the character reacting in a strip under the game -> "Adventure Complete!" with stars and a collectible -> "How do you feel now?" -> Kara reacts -> back on the journey map, where the new mood picks the next world.

Journey map: START at the bottom, six worlds, Star Island at the top. The engine always opens the world it recommends; finishing a world opens the next; Star Island opens when every world is done. "Open every world" in Settings is a demo switch.

Rewards (participation and completion only, never speed or accuracy): 3 stars per finished world (+1 the first time), a collectible per world (flower, butterfly, magic gem, rainbow piece), 1 star for a real attempt, and a garden decoration at 1/3/6/10/15 completions. Nothing is ever lost.

## Research data is unchanged in spirit
Characters and story are presentation only. Each session still records emotion before and after, world, level, pace, condition, completion, success/mistake counts, accuracy (null when a game has no right/wrong moments), average response time (secondary), completed units, pause count, load time, the full decision, and `moodImproved`. Export it from Settings > "Copy game session log (JSON)".

## Swapping in real art
Drop PNGs into `assets/characters/<name>/idle.png` (plus optional happy / excited / calm / encouraging / celebrating) and `assets/worlds/<world>/background.png`. They are used automatically; missing files fall back to the built-in drawings. Game code never touches character graphics.

## Section 18 checklist, answered honestly
* Original characters: yes. Visually consistent: yes (one drawing style).
* 4-6 recurring characters: six. In gameplay and reacting: yes. Positive completion: yes.
* Support regulation: Twinkle's breathing words and the calm Garden; no shaming, no competition, no medical claims (a test scans every line for banned words).
* Modular assets: yes (folders + fallback).
* Different mechanics: breathing, tap/catch, memory, pattern, drag/arrange, navigation.
* **Quality warning:** the characters are simple shapes drawn in code. They are consistent and cheerful, but they are not professional illustration. For a polished look, commission or create real art and use the swap-in folders above.

## Decisions you should know about
* **Name clash:** your brief makes Kara the unicorn companion, but in the proposal KARA is also the IoT robot. I kept the unicorn as you asked and labelled the robot card "KARA robot" (the smart-toy button on the map). You may want a different name for one of them before your defence.
* The old 12 therapeutic games and 4 originals from v5 were **removed**; the six worlds replace them. Old files are only in your v5 zip.
* Still in memory only (lost on restart), same as v5. KARA robot link is still a stub. Reports and reminders unchanged.
* Sounds are soft synthesized tones I generated, not recorded music.
* Memory/pattern games use short `Future.delayed` pauses; they do not freeze during the pause screen.
