import 'package:flutter/material.dart';
import '../services/avatar_service.dart';
import 'avatar_painter.dart';

/// THE CHILD'S FRIEND, anywhere it needs to appear.
///
/// Reads the one shared source of truth (`AvatarService.instance.active`)
/// and rebuilds whenever the child changes their look, so every screen
/// updates at once and no screen keeps its own copy.
///
/// Use this instead of reading `AvatarService` directly. A screen that
/// builds its own companion is how the app ended up showing a different
/// character on every screen in the first place.
///
/// `active` never returns null -- a child who has made nothing still has a
/// default friend to draw -- so there is no empty case to handle here.
class FriendView extends StatelessWidget {
  final double size;
  final bool animate;

  const FriendView({super.key, this.size = 96, this.animate = true});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: AvatarService.instance,
        builder: (context, _) => AvatarView(
          AvatarService.instance.active,
          size: size,
          animate: animate,
        ),
      );
}
