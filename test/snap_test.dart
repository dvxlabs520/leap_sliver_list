import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

void main() {
  useDeterministicBudget();

  double heightOf(int i) => 60.0 + (i * 37 % 50);

  Future<(ScrollController, ListController)> pump(
    WidgetTester tester, {
    double alignment = 0.0,
    double alignmentOffset = 0.0,
  }) async {
    final controller = ScrollController();
    final list = ListController();
    addTearDown(controller.dispose);
    addTearDown(list.dispose);
    await pumpList(
      tester,
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            height: 500,
            child: CustomScrollView(
              key: const ValueKey("scroll"),
              controller: controller,
              physics: ItemSnapScrollPhysics(
                listController: list,
                alignment: alignment,
                alignmentOffset: alignmentOffset,
                parent: const ClampingScrollPhysics(),
              ),
              slivers: [
                SuperSliverList.builder(
                  listController: list,
                  extentPrecalculationPolicy: PreciseExtents(),
                  itemCount: 300,
                  itemBuilder: (_, i) => tile(i, heightOf(i)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return (controller, list);
  }

  double viewportTop(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const ValueKey("scroll"))).dy;

  /// Whether some built item sits at [position] (item leading edge, relative
  /// to the viewport) within a tolerance.
  bool someItemTopIs(WidgetTester tester, double position) {
    for (var i = 0; i < 300; ++i) {
      final finder = find.byKey(ValueKey<int>(i));
      if (finder.evaluate().isEmpty) continue;
      final top = tester.getTopLeft(finder).dy - viewportTop(tester);
      if ((top - position).abs() < 0.01) return true;
    }
    return false;
  }

  testWidgets("snapTarget returns the nearest item offset", (tester) async {
    final (_, list) = await pump(tester);
    // Items 0 and 1 leading edges.
    final offset1 = list.offsetForIndex(1);
    final offset2 = list.offsetForIndex(2);
    final near1 = list.snapTarget(offset1 + 5);
    expect(near1!.index, 1);
    expect(near1.offset, moreOrLessEquals(offset1));
    final near2 = list.snapTarget(offset2 - 5);
    expect(near2!.index, 2);
    expect(near2.offset, moreOrLessEquals(offset2));
  });

  testWidgets("a slow drag settles on an item (alignment 0)", (tester) async {
    await pump(tester);
    await tester.drag(
      find.byKey(const ValueKey("scroll")),
      const Offset(0, -95),
    );
    await tester.pumpAndSettle();
    expect(someItemTopIs(tester, 0), isTrue);
  });

  testWidgets("a fling settles on an item (alignment 0)", (tester) async {
    final (controller, _) = await pump(tester);
    await tester.fling(
      find.byKey(const ValueKey("scroll")),
      const Offset(0, -300),
      1500,
    );
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(500));
    expect(someItemTopIs(tester, 0), isTrue);
  });

  testWidgets("snapping honors alignmentOffset", (tester) async {
    await pump(tester, alignmentOffset: 20);
    await tester.drag(
      find.byKey(const ValueKey("scroll")),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(someItemTopIs(tester, 20), isTrue);
  });

  testWidgets("snapping with alignment 0.5 centers an item", (tester) async {
    await pump(tester, alignment: 0.5);
    await tester.drag(
      find.byKey(const ValueKey("scroll")),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    var centered = false;
    for (var i = 0; i < 300 && !centered; ++i) {
      final finder = find.byKey(ValueKey<int>(i));
      if (finder.evaluate().isEmpty) continue;
      final rect = tester.getRect(finder);
      final center = rect.center.dy - viewportTop(tester);
      centered = (center - 250).abs() < 0.01;
    }
    expect(centered, isTrue);
  });

  testWidgets("does not snap beyond the scroll extent", (tester) async {
    final (controller, _) = await pump(tester);
    await tester.fling(
      find.byKey(const ValueKey("scroll")),
      const Offset(0, 400),
      3000,
    );
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    await tester.fling(
      find.byKey(const ValueKey("scroll")),
      const Offset(0, -400),
      50000,
    );
    await tester.pumpAndSettle();
    expect(
      controller.offset,
      lessThanOrEqualTo(controller.position.maxScrollExtent),
    );
  });
}
