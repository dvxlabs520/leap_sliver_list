import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

void main() {
  useDeterministicBudget();

  // Two kinds of items: small rows (50 px) and big cards (300 px). The first
  // 40 items are mostly small rows, the rest of the list is mostly cards, so
  // the average of what was measured first says nothing about the rest.
  const count = 400;
  bool isCard(int i) => i < 40 ? i % 10 < 2 : i % 10 < 8;
  double heightOf(int i) => isCard(i) ? 300.0 : 50.0;
  int typeOf(int i) => isCard(i) ? 1 : 0;

  double trueTotal() {
    var sum = 0.0;
    for (var i = 0; i < count; ++i) {
      sum += heightOf(i);
    }
    return sum;
  }

  Widget build({
    required ScrollController scroll,
    required ListController list,
    bool adaptive = false,
    ItemTypeOf? itemTypeOf,
    bool separated = false,
    bool scrollAnchoring = true,
    int itemCount = count,
    double Function(int)? height,
  }) {
    Widget item(int i) => tile(i, (height ?? heightOf)(i));
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          height: 500,
          child: CustomScrollView(
            controller: scroll,
            physics: const ClampingScrollPhysics(),
            slivers: [
              if (separated)
                SuperSliverList.separated(
                  listController: list,
                  adaptiveEstimation: adaptive,
                  itemTypeOf: itemTypeOf,
                  scrollAnchoring: scrollAnchoring,
                  itemCount: itemCount,
                  itemBuilder: (_, i) => item(i),
                  separatorBuilder: (_, i) => const SizedBox(height: 10),
                )
              else
                SuperSliverList.builder(
                  listController: list,
                  adaptiveEstimation: adaptive,
                  itemTypeOf: itemTypeOf,
                  scrollAnchoring: scrollAnchoring,
                  itemCount: itemCount,
                  itemBuilder: (_, i) => item(i),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> scrollThrough(
    WidgetTester tester,
    ScrollController scroll,
    double to,
  ) async {
    while (scroll.offset < to) {
      scroll.jumpTo((scroll.offset + 450).clamp(0, to));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<double> estimateError(
    WidgetTester tester, {
    required bool adaptive,
    ItemTypeOf? itemTypeOf,
  }) async {
    final scroll = ScrollController();
    final list = ListController();
    addTearDown(scroll.dispose);
    addTearDown(list.dispose);
    await pumpList(
      tester,
      build(
        scroll: scroll,
        list: list,
        adaptive: adaptive,
        itemTypeOf: itemTypeOf,
      ),
    );
    await scrollThrough(tester, scroll, 1500);
    final error = (list.totalExtent - trueTotal()).abs() / trueTotal();
    // Unmount so that the next run starts from scratch.
    await tester.pumpWidget(const SizedBox());
    return error;
  }

  testWidgets("per type estimate beats the plain average", (tester) async {
    final plain = await estimateError(tester, adaptive: true);
    final typed = await estimateError(
      tester,
      adaptive: false,
      itemTypeOf: typeOf,
    );
    // Both kinds of items were seen, so each type is estimated exactly.
    expect(typed, lessThan(0.02));
    expect(plain, greaterThan(0.2));
    expect(typed, lessThan(plain / 10));
  });

  testWidgets("it is opt in", (tester) async {
    final off = await estimateError(tester, adaptive: false);
    // The default estimate (100 px) is far off.
    expect(off, greaterThan(0.3));
  });

  testWidgets("works with separators", (tester) async {
    final scroll = ScrollController();
    final list = ListController();
    addTearDown(scroll.dispose);
    addTearDown(list.dispose);
    await pumpList(
      tester,
      build(scroll: scroll, list: list, itemTypeOf: typeOf, separated: true),
    );
    await scrollThrough(tester, scroll, 1500);
    final expected = trueTotal() + (count - 1) * 10;
    expect((list.totalExtent - expected).abs() / expected, lessThan(0.02));
  });

  testWidgets("keeps visible items in place while estimates change", (
    tester,
  ) async {
    final scroll = ScrollController();
    final list = ListController();
    addTearDown(scroll.dispose);
    addTearDown(list.dispose);
    await pumpList(
      tester,
      build(
        scroll: scroll,
        list: list,
        itemTypeOf: typeOf,
        scrollAnchoring: false,
        // The extents vary within a type, so the estimates keep changing.
        height: (i) => heightOf(i) + (i * 7919 % 13) * 6,
      ),
    );
    // Items above the viewport were never measured.
    scroll.jumpTo(20000);
    await tester.pumpAndSettle();
    final initialMax = scroll.position.maxScrollExtent;
    final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    final keyed = find.byWidgetPredicate((w) => w.key is ValueKey<int>);
    for (var step = 0; step < 150; ++step) {
      final item = keyed.evaluate().first.widget.key!;
      final before = tester.getTopLeft(find.byKey(item)).dy;
      scroll.jumpTo(scroll.offset + 120);
      await tester.pump();
      // Wherever the estimates are, every built item sits at the offset the
      // list reports for it.
      for (final element in keyed.evaluate()) {
        final index = (element.widget.key! as ValueKey<int>).value;
        expect(
          tester.getTopLeft(find.byWidget(element.widget)).dy - top,
          moreOrLessEquals(
            list.offsetForIndex(index) - scroll.offset,
            epsilon: 0.01,
          ),
          reason: "step $step, item $index",
        );
      }
      final finder = find.byKey(item);
      if (finder.evaluate().isEmpty) {
        continue;
      }
      expect(
        before - tester.getTopLeft(finder).dy,
        moreOrLessEquals(120, epsilon: 0.01),
        reason: "step $step",
      );
    }
    expect(scroll.position.maxScrollExtent, isNot(initialMax));
  });

  testWidgets("items inserted later use the estimate of their type", (
    tester,
  ) async {
    final scroll = ScrollController();
    final list = ListController();
    addTearDown(scroll.dispose);
    addTearDown(list.dispose);
    await pumpList(
      tester,
      build(scroll: scroll, list: list, itemTypeOf: typeOf),
    );
    await scrollThrough(tester, scroll, 1500);
    final before = list.totalExtent;
    // Items appended at the end are of the same type as items 40+ and use
    // their estimate instead of the average of the measured items.
    await pumpList(
      tester,
      build(scroll: scroll, list: list, itemTypeOf: typeOf, itemCount: 410),
    );
    var added = 0.0;
    for (var i = count; i < 410; ++i) {
      added += heightOf(i);
    }
    expect(list.totalExtent - before, closeTo(added, added * 0.05));
  });

  testWidgets("jumpToItem lands on the item", (tester) async {
    final scroll = ScrollController();
    final list = ListController();
    addTearDown(scroll.dispose);
    addTearDown(list.dispose);
    await pumpList(
      tester,
      build(scroll: scroll, list: list, itemTypeOf: typeOf),
    );
    list.jumpToItem(index: 300, scrollController: scroll, alignment: 0.0);
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<int>(300))).dy - top,
      closeTo(0, 0.01),
    );
  });
}
