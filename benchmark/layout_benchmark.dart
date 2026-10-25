// Simple, reproducible benchmark comparing SliverList with SuperSliverList.
//
// Run with:
//
//     flutter test benchmark/layout_benchmark.dart
//
// The benchmark runs in the headless flutter_tester (debug/JIT, no GPU), so it
// measures build + layout + paint-phase cost on the CPU, not rendering speed on
// a device. Use it to compare the two list implementations and to spot
// regressions between versions on the same machine, not as absolute numbers.
//
// Tune with --dart-define, e.g. `--dart-define=ITEMS=100000`.
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

const _items = int.fromEnvironment("ITEMS", defaultValue: 10000);
const _frames = int.fromEnvironment("FRAMES", defaultValue: 300);
const _runs = int.fromEnvironment("RUNS", defaultValue: 5);

/// Deterministic pseudo random item height between 40 and 129 logical pixels.
double _height(int index) => 40.0 + (index * 37 % 90);

Widget _item(BuildContext context, int index) {
  return SizedBox(
    height: _height(index),
    child: Row(
      children: [Text("Item $index"), const Spacer(), const Text("x")],
    ),
  );
}

enum _Kind { sliverList, superSliverList }

Widget _build(_Kind kind, ScrollController controller, ListController list) {
  final sliver = switch (kind) {
    _Kind.sliverList => SliverList.builder(
      itemCount: _items,
      itemBuilder: _item,
    ),
    _Kind.superSliverList => SuperSliverList.builder(
      listController: list,
      itemCount: _items,
      itemBuilder: _item,
    ),
  };
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: CustomScrollView(
        controller: controller,
        physics: const ClampingScrollPhysics(),
        slivers: [sliver],
      ),
    ),
  );
}

class _Stats {
  _Stats(List<double> samples)
    : mean = samples.reduce((a, b) => a + b) / samples.length,
      median = _percentile(samples, 0.5),
      p95 = _percentile(samples, 0.95),
      max = samples.reduce(math.max);
  final double mean;
  final double median;
  final double p95;
  final double max;

  static double _percentile(List<double> samples, double p) {
    final sorted = [...samples]..sort();
    return sorted[((sorted.length - 1) * p).round()];
  }

  @override
  String toString() =>
      "mean ${mean.toStringAsFixed(2)} ms, median ${median.toStringAsFixed(2)} ms, "
      "p95 ${p95.toStringAsFixed(2)} ms, max ${max.toStringAsFixed(2)} ms";
}

/// Time of a single frame in milliseconds.
Future<double> _frame(WidgetTester tester) async {
  final stopwatch = Stopwatch()..start();
  await tester.pump(const Duration(milliseconds: 16));
  return stopwatch.elapsedMicroseconds / 1000.0;
}

void main() {
  final results = <String>[];

  tearDownAll(() {
    // ignore: avoid_print
    print("\n===== leap_sliver_list benchmark =====");
    // ignore: avoid_print
    print("items: $_items, frames per run: $_frames, runs: $_runs");
    for (final line in results) {
      // ignore: avoid_print
      print(line);
    }
  });

  for (final kind in _Kind.values) {
    testWidgets("${kind.name}: scroll down in 120px steps", (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      final list = ListController();
      addTearDown(controller.dispose);
      addTearDown(list.dispose);
      await tester.pumpWidget(_build(kind, controller, list));
      await tester.pump();

      final samples = <double>[];
      for (var run = 0; run < _runs; ++run) {
        controller.jumpTo(0);
        await tester.pump();
        for (var frame = 0; frame < _frames; ++frame) {
          controller.jumpTo(controller.offset + 120);
          samples.add(await _frame(tester));
        }
      }
      results.add("${kind.name} scroll 120px/frame: ${_Stats(samples)}");
    });

    testWidgets("${kind.name}: fast scroll in 5000px steps", (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      final list = ListController();
      addTearDown(controller.dispose);
      addTearDown(list.dispose);
      await tester.pumpWidget(_build(kind, controller, list));
      await tester.pump();

      final samples = <double>[];
      for (var run = 0; run < _runs; ++run) {
        controller.jumpTo(0);
        await tester.pump();
        for (var frame = 0; frame < _frames; ++frame) {
          controller.jumpTo(controller.offset + 5000);
          samples.add(await _frame(tester));
        }
      }
      results.add("${kind.name} scroll 5000px/frame: ${_Stats(samples)}");
    });
  }

  testWidgets("superSliverList: jumpToItem to a far, unbuilt item", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    final list = ListController();
    addTearDown(controller.dispose);
    addTearDown(list.dispose);
    await tester.pumpWidget(_build(_Kind.superSliverList, controller, list));
    await tester.pump();

    final samples = <double>[];
    final random = math.Random(42);
    for (var run = 0; run < _runs * 10; ++run) {
      final target = random.nextInt(_items);
      final stopwatch = Stopwatch()..start();
      list.jumpToItem(
        index: target,
        scrollController: controller,
        alignment: 0,
      );
      await tester.pumpAndSettle();
      samples.add(stopwatch.elapsedMicroseconds / 1000.0);
      expect(find.text("Item $target"), findsOneWidget);
    }
    results.add(
      "superSliverList jumpToItem + settle (random item): ${_Stats(samples)}",
    );
  });
}
