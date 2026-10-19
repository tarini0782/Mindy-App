import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Frame loop for games that move things every frame.
///
/// Uses a Ticker, so it is automatically frozen while the game shell's
/// TickerMode is disabled (pause) and needs no timers to clean up.
/// Long gaps (after a pause) are clamped so nothing "jumps".
///
/// Usage:
///   class _S extends State<W>
///       with SingleTickerProviderStateMixin<W>, GameLoop<W> {
///     void initState() { super.initState(); startLoop(); }
///     void onFrame(double dt) { ... setState(...) ... }
///   }
mixin GameLoop<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  Ticker? _loopTicker;
  Duration _lastElapsed = Duration.zero;

  /// Called once per frame with seconds since the previous frame
  /// (never more than 0.05).
  void onFrame(double dt);

  void startLoop() {
    _loopTicker ??= createTicker(_handleTick)..start();
  }

  void stopLoop() {
    _loopTicker?.dispose();
    _loopTicker = null;
  }

  void _handleTick(Duration elapsed) {
    var dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    if (dt < 0) dt = 0;
    if (dt > 0.05) dt = 0.05;
    if (!mounted) return;
    onFrame(dt);
  }

  @override
  void dispose() {
    stopLoop();
    super.dispose();
  }
}
