import 'package:flutter/material.dart';

class ChartSeries {
  final String name;
  final Color color;
  final List<double?> values; // null = gap
  const ChartSeries(this.name, this.color, this.values);
}

/// Minimal line chart drawn from REAL data only. Shows an empty state
/// when no series has any value.
class SimpleLineChart extends StatelessWidget {
  final List<ChartSeries> series;
  final double yMin;
  final double yMax;
  final String yLabelMin;
  final String yLabelMax;
  final double height;

  const SimpleLineChart({
    super.key,
    required this.series,
    required this.yMin,
    required this.yMax,
    required this.yLabelMin,
    required this.yLabelMax,
    this.height = 150,
  });

  bool get _hasData => series.any((s) => s.values.any((v) => v != null));

  @override
  Widget build(BuildContext context) {
    if (!_hasData) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No data yet', style: TextStyle(color: Colors.black45)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _ChartPainter(series, yMin, yMax, yLabelMin, yLabelMax),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          children: [
            for (final s in series)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, color: s.color),
                const SizedBox(width: 4),
                Text(s.name, style: const TextStyle(fontSize: 12)),
              ]),
          ],
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<ChartSeries> series;
  final double yMin, yMax;
  final String lMin, lMax;
  _ChartPainter(this.series, this.yMin, this.yMax, this.lMin, this.lMax);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0;
    const pad = 8.0;
    final w = size.width - left - pad;
    final h = size.height - pad * 2;
    final grid = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, pad), Offset(left, pad + h), grid);
    canvas.drawLine(Offset(left, pad + h), Offset(left + w, pad + h), grid);
    canvas.drawLine(Offset(left, pad), Offset(left + w, pad), grid);

    void label(String t, double y) {
      final tp = TextPainter(
        text: TextSpan(
            text: t,
            style: const TextStyle(fontSize: 10, color: Colors.black54)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 4);
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    label(lMax, pad);
    label(lMin, pad + h);

    final n = series.map((s) => s.values.length).fold<int>(0, (a, b) => a > b ? a : b);
    if (n == 0) return;
    double xOf(int i) => n == 1 ? left + w / 2 : left + w * i / (n - 1);
    double yOf(double v) {
      final f = ((v - yMin) / (yMax - yMin)).clamp(0.0, 1.0).toDouble();
      return pad + h * (1 - f);
    }

    for (final s in series) {
      final line = Paint()
        ..color = s.color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final dot = Paint()..color = s.color;
      Offset? prev;
      for (var i = 0; i < s.values.length; i++) {
        final v = s.values[i];
        if (v == null) {
          prev = null;
          continue;
        }
        final p = Offset(xOf(i), yOf(v));
        if (prev != null) canvas.drawLine(prev, p, line);
        canvas.drawCircle(p, 4, dot);
        prev = p;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}
