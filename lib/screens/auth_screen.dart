import 'dart:math';
import 'package:flutter/material.dart';
import '../services/account_service.dart';
import '../theme/app_theme.dart';
import '../widgets/adventure_mark.dart';

/// Sign in / create a caregiver account (local to this device).
///
/// v40: this is a GROWN-UP screen, so it is deliberately the darkest
/// surface in the app — a forest at dusk with a lit lantern, rather than
/// the bright child-facing world behind it. The unicorn emoji that used
/// to head it is gone; see `widgets/adventure_mark.dart` for why.
///
/// Every colour pairing here was measured against WCAG 2.1 rather than
/// chosen by eye, because dark surfaces are where contrast quietly fails.
/// The ratios are recorded beside the tokens in `CalmColors`; the lowest
/// on this screen is the fine print at 4.89:1, against a 4.5:1 bar.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _code = TextEditingController();
  bool _register = false;
  bool _researcher = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _pass2.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final a = AccountService.instance;
    String? err;
    if (_register) {
      if (_pass.text != _pass2.text) {
        err = 'The two passwords are different.';
      } else {
        err = await a.register(
          username: _user.text,
          password: _pass.text,
          asResearcher: _researcher,
          studyCodeEntered: _code.text,
        );
      }
    } else {
      err = await a.login(_user.text, _pass.text);
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalmColors.duskTop,
      body: Stack(
        children: [
          // The forest at dusk. Static and cheap: it paints once.
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _DuskPainter()),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: AdventureMark(size: 104)),
                      const SizedBox(height: 4),
                      Text(
                          _register
                              ? 'Create a grown-up account'
                              : 'Welcome to Mindy',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: CalmColors.duskInk)),
                      const SizedBox(height: 8),
                      const Text(
                          'This account is for the parent or caregiver. '
                          'Children get a profile with a nickname only.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15, color: CalmColors.duskInkSoft)),
                      const SizedBox(height: 22),
                      _field(controller: _user, label: 'Username'),
                      const SizedBox(height: 12),
                      _field(
                        controller: _pass,
                        label: 'Password',
                        obscure: true,
                        helper: _register
                            ? 'At least 8 characters, a letter and a number'
                            : null,
                      ),
                      if (_register) ...[
                        const SizedBox(height: 12),
                        _field(
                            controller: _pass2,
                            label: 'Repeat password',
                            obscure: true),
                        if (AccountService.studyCode.isNotEmpty)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _researcher,
                            onChanged: (v) =>
                                setState(() => _researcher = v ?? false),
                            activeColor: CalmColors.treasure,
                            checkColor: CalmColors.onTreasure,
                            side: const BorderSide(
                                color: CalmColors.duskHint, width: 1.6),
                            title: const Text('I am part of the research team',
                                style: TextStyle(color: CalmColors.duskInk)),
                          ),
                        if (_researcher) ...[
                          const SizedBox(height: 12),
                          _field(
                              controller: _code,
                              label: 'Study code',
                              obscure: true),
                        ],
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: CalmColors.duskDanger,
                                  fontWeight: FontWeight.w700)),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CalmColors.treasure,
                            foregroundColor: CalmColors.onTreasure,
                            disabledBackgroundColor: CalmColors.treasureDeep,
                            disabledForegroundColor: CalmColors.onTreasure,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadii.md)),
                          ),
                          child: Text(
                              _busy
                                  ? 'Please wait...'
                                  : (_register ? 'Create account' : 'Sign in'),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => setState(() {
                          _register = !_register;
                          _error = null;
                        }),
                        style: TextButton.styleFrom(
                            foregroundColor: CalmColors.duskLink),
                        child: Text(
                            _register
                                ? 'I already have an account'
                                : 'Create a new account',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      if (!_register)
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    setState(() {
                                      _busy = true;
                                      _error = null;
                                    });
                                    final err = await AccountService.instance
                                        .startDemo();
                                    if (mounted) {
                                      setState(() {
                                        _busy = false;
                                        _error = err;
                                      });
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: CalmColors.duskLink,
                              side: const BorderSide(
                                  color: CalmColors.duskLink, width: 1.6),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.md)),
                            ),
                            icon: const Icon(Icons.play_circle_outline_rounded),
                            label: const Text(
                                'Try the demo (sample child, nothing uploaded)',
                                textAlign: TextAlign.center),
                          ),
                        ),
                      const SizedBox(height: 14),
                      // v48: this was headed "Prototype note:". It is not a
                      // safety statement, just a limitation the caregiver
                      // needs to know before they choose a password, so it
                      // now reads as plain help rather than lab-speak.
                      const Text(
                          'Your account is saved on this device only. If you '
                          'forget your password, the account and its data '
                          'have to be removed and set up again.',
                          style: TextStyle(
                              fontSize: 12.5, color: CalmColors.duskFine),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One dark field. Written once here rather than repeated four times,
  /// so the four inputs cannot drift apart.
  Widget _field({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    String? helper,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      style: const TextStyle(color: CalmColors.duskInk, fontSize: 16),
      cursorColor: CalmColors.treasure,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        filled: true,
        fillColor: CalmColors.duskField,
        labelStyle: const TextStyle(color: CalmColors.duskHint),
        floatingLabelStyle: const TextStyle(color: CalmColors.duskLink),
        helperStyle: const TextStyle(color: CalmColors.duskHint, fontSize: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: Color(0xFF34605B), width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: CalmColors.treasure, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    );
  }
}

/// A forest at dusk: sky, moon, fixed stars, two hill bands and a
/// silhouetted treeline. Nothing moves and nothing repaints — a sign-in
/// screen has no reason to animate, and a still background keeps the
/// lantern the only thing drawing the eye.
class _DuskPainter extends CustomPainter {
  const _DuskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: CalmColors.dusk,
          stops: [0.0, 0.58, 1.0],
        ).createShader(rect),
    );

    // Moon with a soft halo, kept to one corner so it never sits behind
    // the form.
    final moon = Offset(w * 0.84, h * 0.11);
    canvas.drawCircle(moon, h * 0.075, Paint()..color = const Color(0x18FFF4CF));
    canvas.drawCircle(moon, h * 0.045, Paint()..color = const Color(0x2EFFF4CF));
    canvas.drawCircle(moon, h * 0.026, Paint()..color = const Color(0xFFFFF3D6));

    // Stars. Seeded, so the sky is the same every launch.
    final r = Random(11);
    for (var i = 0; i < 54; i++) {
      final x = r.nextDouble() * w;
      final y = r.nextDouble() * h * 0.6;
      canvas.drawCircle(
        Offset(x, y),
        0.6 + r.nextDouble() * 1.4,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, 0.28 + r.nextDouble() * 0.45),
      );
    }

    // Two hill bands.
    void hill(double top, double amp, Color c) {
      const steps = 6;
      final span = w / steps;
      final p = Path()
        ..moveTo(0, h)
        ..lineTo(0, top);
      for (var i = 0; i < steps; i++) {
        final x = i * span;
        p.quadraticBezierTo(
            x + span / 2, top - (i.isEven ? amp : amp * 0.55), x + span, top);
      }
      p
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(p, Paint()..color = c);
    }

    hill(h * 0.70, h * 0.05, const Color(0xFF1A4541));
    hill(h * 0.80, h * 0.035, const Color(0xFF143835));

    // Treeline along the bottom: alternating pines and round canopies,
    // dark enough to read as silhouette rather than as objects.
    final tree = Paint()..color = const Color(0xFF0F2B2A);
    var i = 0;
    for (var x = -20.0; x < w + 30; x += 46) {
      final baseY = h * 0.985;
      if (i.isEven) {
        final tip = baseY - (62 + (i % 3) * 14);
        final p = Path()
          ..moveTo(x, baseY)
          ..lineTo(x + 19, tip)
          ..lineTo(x + 38, baseY)
          ..close();
        canvas.drawPath(p, tree);
      } else {
        canvas.drawRect(
            Rect.fromLTWH(x + 16, baseY - 34, 7, 34), tree);
        canvas.drawCircle(Offset(x + 19, baseY - 42), 21, tree);
      }
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _DuskPainter oldDelegate) => false;
}
