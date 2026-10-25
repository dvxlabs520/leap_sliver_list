import "dart:async";
import "dart:collection";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";

/// Shows how long the last frames took, with a small bar chart.
///
/// Uses the engine frame timings (build + raster) when the platform reports
/// them, and falls back to the interval between frames otherwise. Only frames
/// that are produced while something changes on screen are counted, so scroll
/// or press "Auto scroll" to see numbers. Use a profile or release build for
/// meaningful values.
class FrameMeter extends StatefulWidget {
  const FrameMeter({super.key, this.label});

  final String? label;

  @override
  State<FrameMeter> createState() => FrameMeterState();
}

class FrameMeterState extends State<FrameMeter> {
  static const _maxSamples = 120;

  final _timings = Queue<double>();
  final _intervals = Queue<double>();
  final _stopwatch = Stopwatch()..start();
  int? _lastFrameMicros;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
    _refresh = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  /// Forgets all samples.
  void reset() {
    setState(() {
      _timings.clear();
      _intervals.clear();
    });
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _push(_timings, timing.totalSpan.inMicroseconds / 1000.0);
    }
  }

  void _onFrame(Duration _) {
    final now = _stopwatch.elapsedMicroseconds;
    final last = _lastFrameMicros;
    _lastFrameMicros = now;
    // Gaps longer than 100 ms mean the app was idle, not slow.
    if (last != null && now - last < 100000) {
      _push(_intervals, (now - last) / 1000.0);
    }
  }

  void _push(Queue<double> queue, double value) {
    queue.addLast(value);
    while (queue.length > _maxSamples) {
      queue.removeFirst();
    }
  }

  @override
  Widget build(BuildContext context) {
    final useTimings = _timings.length >= 5;
    final samples = (useTimings ? _timings : _intervals).toList();
    final theme = Theme.of(context);
    final sorted = [...samples]..sort();
    final mean = samples.isEmpty
        ? 0.0
        : samples.reduce((a, b) => a + b) / samples.length;
    final p95 = sorted.isEmpty
        ? 0.0
        : sorted[math.min(sorted.length - 1, (sorted.length * 0.95).floor())];
    final worst = sorted.isEmpty ? 0.0 : sorted.last;
    final style = theme.textTheme.labelMedium;
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null)
              Text(widget.label!, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              samples.isEmpty
                  ? "No frames yet. Scroll the list."
                  : "mean ${mean.toStringAsFixed(1)} ms   "
                      "p95 ${p95.toStringAsFixed(1)} ms   "
                      "worst ${worst.toStringAsFixed(1)} ms",
              style: style,
            ),
            Text(
              useTimings
                  ? "build + raster, last ${samples.length} frames"
                  : "time between frames, last ${samples.length} frames",
              style: style?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              width: double.infinity,
              child: CustomPaint(
                painter: _BarsPainter(
                  samples,
                  theme.colorScheme.primary,
                  theme.colorScheme.error,
                  theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.samples, this.color, this.slowColor, this.guide);

  final List<double> samples;
  final Color color;
  final Color slowColor;
  final Color guide;

  // The chart covers 0 to 33 ms; a 60 Hz frame budget is 16.7 ms.
  static const _scale = 33.0;

  @override
  void paint(Canvas canvas, Size size) {
    final budgetY = size.height * (1 - 16.7 / _scale);
    canvas.drawLine(
      Offset(0, budgetY),
      Offset(size.width, budgetY),
      Paint()..color = guide,
    );
    if (samples.isEmpty) {
      return;
    }
    final barWidth = size.width / _FrameMeterBars.count;
    for (var i = 0; i < samples.length; ++i) {
      final value = samples[i].clamp(0.0, _scale);
      final height = size.height * value / _scale;
      canvas.drawRect(
        Rect.fromLTWH(
          i * barWidth,
          size.height - height,
          math.max(1, barWidth - 1),
          height,
        ),
        Paint()..color = samples[i] > 16.7 ? slowColor : color,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) => true;
}

abstract final class _FrameMeterBars {
  static const count = FrameMeterState._maxSamples;
}
