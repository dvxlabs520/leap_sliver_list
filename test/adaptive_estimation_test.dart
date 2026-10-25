import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

void main() {
  useDeterministicBudget();

  // Items average 200 px, the default estimate is 100 px.
  double heightOf(int i) => 160.0 + (i % 5) * 20;

  Widget build(
    ScrollController controller, {
    required bool adaptive,
    int count = 1000,
    ExtentEstimationProvider? extentEstimation,
    double Function(int)? height,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          height: 500,
          child: CustomScrollView(
            controller: controller,
            physics: const ClampingScrollPhysics(),
            slivers: [
              SuperSliverList.builder(
                adaptiveEstimation: adaptive,
                extentEstimation: extentEstimation,
                itemCount: count,
                itemBuilder: (_, i) => tile(i, (height ?? heightOf)(i)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double trueTotal(int count) {
    var sum = 0.0;
    for (var i = 0; i < count; ++i) {
      sum += heightOf(i);
    }
    return sum;
  }

  Future<void> scrollThrough(
    WidgetTester tester,
    ScrollController controller,
    int steps,
  ) async {
    for (var i = 0; i < steps; ++i) {
      controller.jumpTo(
        (controller.offset + 450).clamp(0, controller.position.maxScrollExtent),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets("default estimate is off by a factor of two", (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpList(tester, build(controller, adaptive: false));
    await scrollThrough(tester, controller, 30);
    final extent = controller.position.maxScrollExtent + 500;
    expect(extent, lessThan(trueTotal(1000) * 0.7));
  });

  testWidgets("adaptive estimate converges to the real extent", (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpList(tester, build(controller, adaptive: true));
    await scrollThrough(tester, controller, 30);
    final extent = controller.position.maxScrollExtent + 500;
    expect(extent, closeTo(trueTotal(1000), trueTotal(1000) * 0.1));
  });

  testWidgets("adaptive estimate keeps visible items in place", (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    // Items get taller towards the end, so the average keeps changing.
    await pumpList(
      tester,
      build(controller, adaptive: true, height: (i) => 60.0 + i * 0.5),
    );
    controller.jumpTo(3000);
    await tester.pumpAndSettle();

    final initialMax = controller.position.maxScrollExtent;
    for (var step = 0; step < 150; ++step) {
      // Pick an item that is visible and remember where it is.
      final item = find
          .byWidgetPredicate((w) => w.key is ValueKey<int>)
          .evaluate()
          .first
          .widget
          .key!;
      final before = tester.getTopLeft(find.byKey(item)).dy;
      final offsetBefore = controller.offset;
      controller.jumpTo(offsetBefore + 120);
      await tester.pump();
      final finder = find.byKey(item);
      if (finder.evaluate().isEmpty) {
        continue;
      }
      expect(
        before - tester.getTopLeft(finder).dy,
        moreOrLessEquals(controller.offset - offsetBefore, epsilon: 0.01),
        reason: "step $step",
      );
    }
    // The estimate did change while scrolling.
    expect(controller.position.maxScrollExtent, isNot(initialMax));
  });

  testWidgets("extentEstimation takes precedence", (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpList(
      tester,
      build(controller, adaptive: true, extentEstimation: (_, _) => 100),
    );
    await scrollThrough(tester, controller, 30);
    final extent = controller.position.maxScrollExtent + 500;
    expect(extent, lessThan(trueTotal(1000) * 0.7));
  });

  testWidgets("adaptive estimate applies to inserted items", (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpList(tester, build(controller, adaptive: true, count: 200));
    await scrollThrough(tester, controller, 12);
    await pumpList(tester, build(controller, adaptive: true, count: 400));
    final extent = controller.position.maxScrollExtent + 500;
    expect(extent, closeTo(trueTotal(400), trueTotal(400) * 0.1));
  });
}
