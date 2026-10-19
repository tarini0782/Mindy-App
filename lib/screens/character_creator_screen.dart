import 'package:flutter/material.dart';
import '../characters/avatar.dart';
import '../characters/avatar_painter.dart';
import '../services/avatar_service.dart';
import '../theme/app_theme.dart';
import '../widgets/calm_ui.dart';

/// CHARACTER CREATOR -- the child makes their own character.
///
/// Design rules for this screen specifically:
///  * every option is free and unlocked; nothing is earned or bought
///  * no option can produce a broken character, so there is no "invalid" state
///  * the preview updates instantly, because that feedback IS the activity
///  * big targets, no reading required to use it (names are there for
///    grown-ups and for screen readers, but the swatches carry the meaning)
class CharacterCreatorScreen extends StatefulWidget {
  /// Editing an existing saved character, or null for a new one.
  final int? editIndex;
  const CharacterCreatorScreen({super.key, this.editIndex});

  @override
  State<CharacterCreatorScreen> createState() => _CharacterCreatorScreenState();
}

class _CharacterCreatorScreenState extends State<CharacterCreatorScreen> {
  late MindyAvatar _a;
  late final TextEditingController _name;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    final svc = AvatarService.instance;
    final i = widget.editIndex;
    _a = (i != null && i >= 0 && i < svc.saved.length)
        ? svc.saved[i]
        : const MindyAvatar();
    _name = TextEditingController(text: _a.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set(MindyAvatar next) => setState(() => _a = next);

  Future<void> _save() async {
    final named = _a.copyWith(
      name: _name.text.trim().isEmpty ? 'My character' : _name.text.trim(),
    );
    await AvatarService.instance.save(named, replaceIndex: widget.editIndex);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${named.name} is ready!')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalmColors.mist,
      appBar: AppBar(
        title: Text(widget.editIndex == null
            ? 'Make your character'
            : 'Change your character'),
      ),
      body: Column(
        children: [
          // ---- live preview -------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: CalmColors.hero,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(children: [
              AvatarView(_a, size: 150, animate: true),
              const SizedBox(height: 6),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _name,
                  textAlign: TextAlign.center,
                  maxLength: 18,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: 'Name your character',
                    hintStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ),

          // ---- category chips -----------------------------------------
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_tabs[i]),
                      selected: _tab == i,
                      onSelected: (_) => setState(() => _tab = i),
                    ),
                  ),
              ],
            ),
          ),

          // ---- options -------------------------------------------------
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              child: _options(),
            ),
          ),

          // ---- save ----------------------------------------------------
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.casino_rounded),
                    label: const Text('Surprise me'),
                    onPressed: () {
                      final p = (AvatarOptions.presets.toList()..shuffle()).first;
                      _name.text = p.name;
                      _set(p);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('This is me!'),
                    onPressed: _save,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static const _tabs = [
    'Skin',
    'Hair',
    'Colour',
    'Clothes',
    'Shoes',
    'Hats',
    'Wings',
    'Face',
    'Extras',
    'Ready-made',
  ];

  Widget _options() {
    switch (_tab) {
      case 0:
        return _swatches(
          AvatarOptions.skins,
          AvatarOptions.skinNames,
          _a.skin,
          (i) => _set(_a.copyWith(skin: i)),
        );
      case 1:
        return _labels(AvatarOptions.hairStyles, _a.hairStyle,
            (i) => _set(_a.copyWith(hairStyle: i)),
            preview: (i) => _a.copyWith(hairStyle: i));
      case 2:
        return _swatches(
          AvatarOptions.hairColors,
          AvatarOptions.hairColorNames,
          _a.hairColor,
          (i) => _set(_a.copyWith(hairColor: i)),
        );
      case 3:
        return Column(children: [
          _labels(AvatarOptions.outfits, _a.outfit,
              (i) => _set(_a.copyWith(outfit: i)),
              preview: (i) => _a.copyWith(outfit: i)),
          const SizedBox(height: 10),
          const SectionLabel('Colour'),
          _swatches(
            AvatarOptions.outfitColors,
            AvatarOptions.outfitColorNames,
            _a.outfitColor,
            (i) => _set(_a.copyWith(outfitColor: i)),
          ),
        ]);
      case 4:
        return _labels(AvatarOptions.shoes, _a.shoes,
            (i) => _set(_a.copyWith(shoes: i)),
            preview: (i) => _a.copyWith(shoes: i));
      case 5:
        return _labels(AvatarOptions.headwear, _a.headwear,
            (i) => _set(_a.copyWith(headwear: i)),
            preview: (i) => _a.copyWith(headwear: i));
      case 6:
        return _labels(AvatarOptions.wings, _a.wings,
            (i) => _set(_a.copyWith(wings: i)),
            preview: (i) => _a.copyWith(wings: i));
      case 7:
        return _labels(AvatarOptions.faces, _a.face,
            (i) => _set(_a.copyWith(face: i)),
            preview: (i) => _a.copyWith(face: i));
      case 8:
        return _labels(AvatarOptions.extras, _a.extra,
            (i) => _set(_a.copyWith(extra: i)),
            preview: (i) => _a.copyWith(extra: i));
      default:
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final p in AvatarOptions.presets)
              InkWell(
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: () {
                  _name.text = p.name;
                  _set(p);
                },
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: CalmColors.cardBorder),
                  ),
                  child: Column(children: [
                    AvatarView(p, size: 86),
                    const SizedBox(height: 6),
                    Text(p.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: CalmColors.ink)),
                  ]),
                ),
              ),
          ],
        );
    }
  }

  /// Colour choices: the swatch itself carries the meaning.
  Widget _swatches(List<Color> colors, List<String> names, int selected,
      ValueChanged<int> onPick) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < colors.length; i++)
          Semantics(
            label: names[i],
            selected: selected == i,
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: () => onPick(i),
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == i ? CalmColors.teal : Colors.black12,
                    width: selected == i ? 4 : 1.5,
                  ),
                ),
                child: selected == i
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 26)
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  /// Shape choices: each tile previews the change on the child's own
  /// character, so they can see what they are picking before they pick it.
  Widget _labels(List<String> names, int selected, ValueChanged<int> onPick,
      {required MindyAvatar Function(int) preview}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < names.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: () => onPick(i),
            child: Container(
              width: 104,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: selected == i ? CalmColors.teal : CalmColors.cardBorder,
                  width: selected == i ? 3 : 1.5,
                ),
              ),
              child: Column(children: [
                AvatarView(preview(i), size: 64),
                const SizedBox(height: 2),
                Text(names[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          selected == i ? FontWeight.w800 : FontWeight.w600,
                      color: CalmColors.ink,
                    )),
              ]),
            ),
          ),
      ],
    );
  }
}

/// The "my characters" list: switch between saved characters, edit or
/// delete one, or make another.
class MyCharactersScreen extends StatelessWidget {
  const MyCharactersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = AvatarService.instance;
    return Scaffold(
      backgroundColor: CalmColors.mist,
      appBar: AppBar(title: const Text('My characters')),
      body: AnimatedBuilder(
        animation: svc,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (svc.saved.isEmpty)
                const CalmCard(
                  child: Text(
                      'No characters yet. Tap "Make a new character" to make one.',
                      style: TextStyle(fontSize: 15, color: CalmColors.ink)),
                ),
              for (var i = 0; i < svc.saved.length; i++)
                CalmCard(
                  tint: i == svc.activeIndex ? CalmColors.tealSoft : null,
                  onTap: () => svc.setActive(i),
                  child: Row(children: [
                    AvatarView(svc.saved[i], size: 64),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(svc.saved[i].name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: CalmColors.ink)),
                            if (i == svc.activeIndex)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text('Playing as this one',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: CalmColors.inkSoft)),
                              ),
                          ]),
                    ),
                    IconButton(
                      tooltip: 'Change',
                      icon: const Icon(Icons.edit_rounded),
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  CharacterCreatorScreen(editIndex: i))),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => svc.delete(i),
                    ),
                  ]),
                ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Make a new character'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CharacterCreatorScreen())),
              ),
            ],
          );
        },
      ),
    );
  }
}
