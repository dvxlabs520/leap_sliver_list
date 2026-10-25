import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

void main() {
  useDeterministicBudget();

  double heightOf(int i) => 40.0 + (i * 37 % 60);

  double topOf(WidgetTester tester, int index) =>
      tester.getTopLeft(find.byKey(ValueKey<int>(index))).dy -
      tester.getTopLeft(find.byType(Scrollable)).dy;

  for (final precise in [true, false]) {
    final suffix = precise ? "precise" : "estimated";

    testWidgets("initialItem at the leading edge, first frame ($suffix)", (
      tester,
    ) async {
      final controller = ScrollController();
      final list = ListController();
      addTearDown(controller.dispose);
      addTearDown(list.dispose);
      // Only the first frame, no settling: there is no flash of item 0.
      await tester.pumpWidget(
        buildSingleList(
          itemCount: 300,
          height: heightOf,
          listController: list,
          scrollController: controller,
          precise: precise,
          initialItem: const ItemPosition(index: 150),
        ),
      );
      expect(find.byKey(const ValueKey<int>(0)), findsNothing);
      expect(topOf(tester, 150), moreOrLessEquals(0));
      await tester.pumpAndSettle();
      expect(topOf(tester, 150), moreOrLessEquals(0));
    });

    testWidgets("initialItem centered with offset ($suffix)", (tester) async {
      final controller = ScrollController();
      final list = ListController();
      addTearDown(controller.dispose);
      addTearDown(list.dispose);
      await pumpList(
        tester,
        buildSingleList(
          itemCount: 300,
          height: heightOf,
          listController: list,
          scrollController: controller,
          precise: precise,
          initialItem: const ItemPosition(
            index: 200,
            alignment: 0.5,
            alignmentOffset: 10,
          ),
        ),
      );
      expect(
        topOf(tester, 200),
        moreOrLessEquals((500 - heightOf(200)) / 2 + 10),
      );
    });
  }

  testWidgets("initialItem on the last item does not overscroll", (
    tester,
  ) async {
    final controller = ScrollController();
    final list = ListController();
    addTearDown(controller.dispose);
    addTearDown(list.dispose);
    await pumpList(
      tester,
      buildSingleList(
        itemCount: 100,
        height: heightOf,
        listController: list,
        scrollController: controller,
        initialItem: const ItemPosition(index: 99),
      ),
    );
    expect(
      controller.offset,
      moreOrLessEquals(controller.position.maxScrollExtent),
    );
    expect(find.byKey(const ValueKey<int>(99)), findsOneWidget);
  });

  testWidgets("initialItem works with separators", (tester) async {
    final controller = ScrollController();
    final list = ListController();
    addTearDown(controller.dispose);
    addTearDown(list.dispose);
    await pumpList(
      tester,
      buildSingleList(
        itemCount: 100,
        height: heightOf,
        separated: true,
        listController: list,
        scrollController: controller,
        initialItem: const ItemPosition(index: 40),
      ),
    );
    expect(topOf(tester, 40), moreOrLessEquals(0));
  });

  testWidgets("initialItem is applied once the list has items, only once", (
    tester,
  ) async {
    final controller = ScrollController();
    final list = ListController();
    addTearDown(controller.dispose);
    addTearDown(list.dispose);
    Widget build(int count) => buildSingleList(
      itemCount: count,
      height: heightOf,
      listController: list,
      scrollController: controller,
      initialItem: const ItemPosition(index: 30),
    );
    await pumpList(tester, build(0));
    expect(controller.offset, 0);
    await pumpList(tester, build(100));
    expect(topOf(tester, 30), moreOrLessEquals(0));

    // The user scrolls away; later updates do not jump back.
    controller.jumpTo(100);
    await tester.pumpAndSettle();
    await pumpList(tester, build(101));
    expect(controller.offset, 100);
  });

  testWidgets("initialItem yields to an explicit initial scroll offset", (
    tester,
  ) async {
    final controller = ScrollController(initialScrollOffset: 300);
    final list = ListController();
    addTearDown(controller.dispose);
    addTearDown(list.dispose);
    await pumpList(
      tester,
      buildSingleList(
        itemCount: 100,
        height: heightOf,
        listController: list,
        scrollController: controller,
        initialItem: const ItemPosition(index: 50),
      ),
    );
    // Item 50 is far away, the explicit offset is kept (up to the correction
    // of estimated extents), so the first items are still the ones in view.
    expect(find.byKey(const ValueKey<int>(50)), findsNothing);
    expect(controller.offset, greaterThan(100));
  });

  testWidgets("SuperListView initialItem", (tester) async {
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
            child: SuperListView.builder(
              controller: controller,
              listController: list,
              itemCount: 300,
              initialItem: const ItemPosition(index: 120, alignment: 1.0),
              itemBuilder: (_, i) => tile(i, heightOf(i)),
            ),
          ),
        ),
      ),
    );
    expect(topOf(tester, 120), moreOrLessEquals(500 - heightOf(120)));
  });
}
