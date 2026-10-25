// Compares the extent estimators of SuperSliverList on lists with mixed row
// heights:
//
//   * default:  every unmeasured item is estimated with a fixed 100 px.
//   * adaptive: `adaptiveEstimation: true` (average of the measured items).
//   * per type: `itemTypeOf` (average of the measured items of the same kind).
//
// Run with:
//
//     flutter test benchmark/estimation_benchmark.dart
//
// Besides the frame time, it reports how far the estimated total extent of the
// list is from the real one after scrolling through the first screens, and how
// much the total extent (the scrollbar) moved while scrolling. The accuracy
// numbers are deterministic; the frame times depend on the machine.
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

const _items = int.fromEnvironment("ITEMS", defaultValue: 10000);
const _screens = int.fromEnvironment("SCREENS", defaultValue: 40);

/// A mixed feed: text rows, image cards and ads, evenly spread.
int _feedKind(int i) {
  final h = (i * 2654435761) % 100;
  return h < 60
      ? 0
      : h < 90
      ? 1
      : 2;
}

/// A list that starts with small rows and continues with mostly cards, so
/// what was measured first does not describe the rest of the list.
int _shiftedKind(int i) {
  final h = (i * 2654435761) % 100;
  if (i < 150) {
    return h < 85 ? 0 : 1;
  }
  return h < 20 ? 0 : 1;
}

const _kindHeights = [60.0, 260.0, 120.0];

class _Scenario {
  const _Scenario(this.name, this.kindOf);
  final String name;
  final int Function(int) kindOf;
  double height(int i) => _kindHeights[kindOf(i)];
  double get total {
    var sum = 0.0;
    for (var i = 0; i < _items; ++i) {
      sum += height(i);
    }
    return sum;
  }
}

enum _Estimator { standard, adaptive, perType }

Widget _build(
  _Scenario scenario,
  _Estimator estimator,
  ScrollController controller,
  ListController list,
) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: CustomScrollView(
        controller: controller,
        physics: const ClampingScrollPhysics(),
        slivers: [
          SuperSliverList.builder(
            listController: list,
            adaptiveEstimation: estimator == _Estimator.adaptive,
            itemTypeOf: estimator == _Estimator.perType
                ? scenario.kindOf
                : null,
            itemCount: _items,
            itemBuilder: (_, i) => SizedBox(
              height: scenario.height(i),
              child: Row(children: [Text("Item $i"), const Spacer()]),
            ),
          ),
        ],
      ),
    ),
  );
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

void main() {
  final lines = <String>[];
  tearDownAll(() {
    // ignore: avoid_print
    print("\n===== leap_sliver_list estimation benchmark =====");
    // ignore: avoid_print
    print("items: $_items, screens scrolled: $_screens (600 px each)");
    for (final line in lines) {
      // ignore: avoid_print
      print(line);
    }
  });

  for (final scenario in [
    const _Scenario("feed", _feedKind),
    const _Scenario("shifted", _shiftedKind),
  ]) {
    for (final estimator in _Estimator.values) {
      testWidgets("${scenario.name}: ${estimator.name}", (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final controller = ScrollController();
        final list = ListController();
        addTearDown(controller.dispose);
        addTearDown(list.dispose);
        await tester.pumpWidget(_build(scenario, estimator, controller, list));
        await tester.pump();

        final truth = scenario.total;
        final initial = list.totalExtent;
        var previous = initial;
        var moved = 0.0;
        final frames = <double>[];
        for (var s = 0; s < _screens; ++s) {
          controller.jumpTo(controller.offset + 600);
          final stopwatch = Stopwatch()..start();
          await tester.pump(const Duration(milliseconds: 16));
          frames.add(stopwatch.elapsedMicroseconds / 1000.0);
          moved += (list.totalExtent - previous).abs();
          previous = list.totalExtent;
        }
        final error = (list.totalExtent - truth).abs() / truth * 100;
        lines.add(
          "${scenario.name.padRight(8)} ${estimator.name.padRight(9)} "
          "estimated total ${list.totalExtent.round()} px "
          "(real ${truth.round()}), error ${error.toStringAsFixed(1)} %, "
          "scrollbar back-and-forth "
          "${(moved - (list.totalExtent - initial).abs()).round()} px, "
          "median frame ${_median(frames).toStringAsFixed(2)} ms, "
          "max frame ${frames.reduce(math.max).toStringAsFixed(2)} ms",
        );
      });
    }
  }
}
