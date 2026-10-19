import 'package:flutter/material.dart';
import '../characters/avatar.dart';
import '../characters/avatar_painter.dart';
import '../services/avatar_service.dart';
import '../theme/app_theme.dart';

/// FIRST RUN -- "Let's make your friend."
///
/// Shown once per child, between the consent gate and the app itself. The
/// friend made here is the companion that guides the child through every
/// screen afterwards (see `CharacterSay.who == null` in the game shell).
///
/// Rules this screen follows:
///  * It is skippable at every step. A child who skips gets the default
///    friend and is never asked again -- `AvatarService.markOnboardingSeen`
///    records that separately from "has made a character", so skipping is
///    respected rather than nagged at.
///  * Nothing here is locked, earned, bought or hidden behind progress.
///  * No option is gendered in its name, and the presets deliberately mix
///    their options so none of them reads as "the one for girls".
///  * Every choice is drawn in code. The project has no character artwork
///    (all 20 asset folders hold only README placeholders), so a friend is
///    a handful of integers and nothing can fail to load.
class FriendOnboardingScreen extends StatefulWidget {
  /// Called when the flow is finished or skipped.
  final VoidCallback onDone;
  const FriendOnboardingScreen({super.key, required this.onDone});

  @override
  State<FriendOnboardingScreen> createState() => _FriendOnboardingScreenState();
}

class _FriendOnboardingScreenState extends State<FriendOnboardingScreen> {
  static const int _lastStep = 3;

  int _step = 0;
  MindyAvatar _avatar = AvatarOptions.presets.first;
  late final TextEditingController _name =
      TextEditingController(text: _avatar.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _skip() async {
    await AvatarService.instance.markOnboardingSeen();
    if (mounted) widget.onDone();
  }

  Future<void> _finish() async {
    final typed = _name.text.trim();
    await AvatarService.instance.save(
        _avatar.copyWith(name: typed.isEmpty ? 'My friend' : typed));
    await AvatarService.instance.markOnboardingSeen();
    if (mounted) widget.onDone();
  }

  void _next() {
    if (_step >= _lastStep) {
      _finish();
      return;
    }
    setState(() => _step++);
  }

  void _choosePreset(MindyAvatar preset) {
    setState(() {
      _avatar = preset;
      _name.text = preset.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The preview is the point of the screen, so it gets the room. On a
    // short screen it shrinks rather than pushing the controls off.
    final h = MediaQuery.of(context).size.height;
    final preview = (h * 0.26).clamp(120.0, 230.0).toDouble();

    return Scaffold(
      backgroundColor: CalmColors.mist,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  for (var i = 0; i <= _lastStep; i++)
                    Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? CalmColors.teal
                              : CalmColors.tealSoft,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: _skip,
                    child: Text('Skip',
                        style: AppText.body.copyWith(
                            color: CalmColors.inkSoft,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  children: [
                    Text(_title,
                        textAlign: TextAlign.center,
                        style: AppText.heading
                            .copyWith(color: CalmColors.ink, fontSize: 25)),
                    const SizedBox(height: 6),
                    Text(_subtitle,
                        textAlign: TextAlign.center,
                        style: AppText.body
                            .copyWith(color: CalmColors.inkSoft)),
                    const SizedBox(height: 14),
                    AvatarView(_avatar, size: preview, animate: true),
                    const SizedBox(height: 14),
                    _body(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CalmColors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadii.md)),
                  ),
                  child: Text(_step >= _lastStep ? "That's my friend!" : 'Next',
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _title => switch (_step) {
        0 => 'Your friend is here with you',
        1 => 'Who would you like with you?',
        2 => 'Make them yours',
        _ => 'What shall we call them?',
      };

  String get _subtitle => switch (_step) {
        0 => 'They will come with you to every activity, and wait with you '
            'whenever you need a quiet moment.',
        1 => 'You can change any of this later.',
        2 => 'Pick the colours you like best.',
        _ => 'Any name you like.',
      };

  Widget _body() => switch (_step) {
        0 => const SizedBox(height: 4),
        1 => _presets(),
        2 => _colours(),
        _ => _nameField(),
      };

  Widget _presets() => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final p in AvatarOptions.presets)
            _Choice(
              selected: _avatar.skin == p.skin &&
                  _avatar.hairStyle == p.hairStyle &&
                  _avatar.outfit == p.outfit,
              onTap: () => _choosePreset(p),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AvatarView(p, size: 62),
                  const SizedBox(height: 2),
                  Text(p.name,
                      style: AppText.body
                          .copyWith(fontSize: 12, color: CalmColors.ink)),
                ],
              ),
            ),
        ],
      );

  Widget _colours() => Column(
        children: [
          _swatches(
            label: 'Skin',
            colors: AvatarOptions.skins,
            index: _avatar.skin,
            onPick: (i) => setState(() => _avatar = _avatar.copyWith(skin: i)),
          ),
          const SizedBox(height: 12),
          _swatches(
            label: 'Hair',
            colors: AvatarOptions.hairColors,
            index: _avatar.hairColor,
            onPick: (i) =>
                setState(() => _avatar = _avatar.copyWith(hairColor: i)),
          ),
          const SizedBox(height: 12),
          _swatches(
            label: 'Clothes',
            colors: AvatarOptions.outfitColors,
            index: _avatar.outfitColor,
            onPick: (i) =>
                setState(() => _avatar = _avatar.copyWith(outfitColor: i)),
          ),
        ],
      );

  Widget _swatches({
    required String label,
    required List<Color> colors,
    required int index,
    required ValueChanged<int> onPick,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppText.subheading.copyWith(color: CalmColors.ink)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (var i = 0; i < colors.length; i++)
                GestureDetector(
                  onTap: () => onPick(i),
                  child: Container(
                    // 48 is the minimum comfortable target for a child.
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == index
                            ? CalmColors.ink
                            : CalmColors.cardBorder,
                        width: i == index ? 3 : 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );

  Widget _nameField() => TextField(
        controller: _name,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.words,
        maxLength: 18,
        style: AppText.heading.copyWith(fontSize: 22, color: CalmColors.ink),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: CalmColors.card,
          hintText: 'My friend',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: CalmColors.cardBorder),
          ),
        ),
      );
}

class _Choice extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _Choice(
      {required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? CalmColors.tealSoft : CalmColors.card,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? CalmColors.teal : CalmColors.cardBorder,
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: child,
        ),
      );
}
