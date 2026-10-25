import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

// Regression tests for upstream issue #83: jumpToItem with `.separated`
// landed at index / 2 because the controller indexed children (items and
// separators) instead of items.
void main() {
  useDeterministicBudget();

  Future<(ListController, ScrollController)> pump(
    WidgetTester tester, {
    int itemCount = 30,
  }) async {
    final list = ListController();
    final scroll = ScrollController();
    addTearDown(list.dispose);
    addTearDown(scroll.dispose);
    await pumpList(
      tester,
      buildSingleList(
        itemCount: itemCount,
        height: (_) => 100,
        separated: true,
        separatorHeight: 10,
        listController: list,
        scrollController: scroll,
      ),
    );
    return (list, scroll);
  }

  group("separated list indexes items", () {
    testWidgets("jumpToItem lands on the requested item", (tester) async {
      final (list, scroll) = await pump(tester);
      list.jumpToItem(index: 10, scrollController: scroll, alignment: 0);
      await tester.pumpAndSettle();
      // Item 10 starts after 10 items and 10 separators.
      expect(scroll.offset, 10 * 110.0);
      expect(find.text("Tile 10"), findsOneWidget);
      expect(list.visibleRange?.$1, 10);
    });

    testWidgets("offsetForIndex / extentForIndex / numberOfItems", (
      tester,
    ) async {
      final (list, _) = await pump(tester);
      expect(list.numberOfItems, 30);
      expect(list.offsetForIndex(3), 330);
      expect(list.extentForIndex(3).$1, 100);
      expect(list.getOffsetToReveal(5, 0), 550);
    });

    testWidgets("animateToItem lands on the requested item", (tester) async {
      final (list, scroll) = await pump(tester);
      list.animateToItem(
        index: () => 12,
        scrollController: scroll,
        alignment: 0,
        duration: (_) => const Duration(milliseconds: 200),
        curve: (_) => Curves.linear,
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, 12 * 110.0);
    });

    testWidgets("visibleRange is reported in items", (tester) async {
      final (list, scroll) = await pump(tester);
      scroll.jumpTo(1100);
      await tester.pumpAndSettle();
      final range = list.visibleRange!;
      expect(range.$1, 10);
      // 500px viewport shows items 10..13 (4 items = 440px + separators).
      expect(range.$2, inInclusiveRange(13, 14));
    });

    testWidgets("addItem / removeItem keep item and separator pairs", (
      tester,
    ) async {
      final (list, _) = await pump(tester, itemCount: 5);
      expect(list.numberOfItems, 5);
      list.addItem(2);
      expect(list.numberOfItems, 6);
      list.removeItem(2);
      expect(list.numberOfItems, 5);
      list.addItem(5); // append
      expect(list.numberOfItems, 6);
      list.removeItem(5); // remove last
      expect(list.numberOfItems, 5);
    });

    testWidgets("firstVisibleIndex / lastVisibleIndex", (tester) async {
      final (list, scroll) = await pump(tester);
      expect(list.firstVisibleIndex, 0);
      scroll.jumpTo(1100);
      await tester.pumpAndSettle();
      expect(list.firstVisibleIndex, 10);
      expect(list.lastVisibleIndex, list.visibleRange!.$2);
    });
  });

  group("SuperListView.separated", () {
    Widget build(ListController list, ScrollController scroll, bool items) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 500,
          child: SuperListView.separated(
            controller: scroll,
            physics: const ClampingScrollPhysics(),
            listController: list,
            listControllerIndexesItems: items,
            extentPrecalculationPolicy: PreciseExtents(),
            itemCount: 30,
            itemBuilder: (_, i) => tile(i, 100),
            separatorBuilder: (_, i) => const SizedBox(height: 10),
          ),
        ),
      );
    }

    testWidgets("indexes items by default", (tester) async {
      final list = ListController();
      final scroll = ScrollController();
      addTearDown(list.dispose);
      addTearDown(scroll.dispose);
      await pumpList(tester, build(list, scroll, true));
      list.jumpToItem(index: 10, scrollController: scroll, alignment: 0);
      await tester.pumpAndSettle();
      expect(scroll.offset, 1100);
      expect(list.numberOfItems, 30);
    });

    testWidgets("can opt out and index all children", (tester) async {
      final list = ListController();
      final scroll = ScrollController();
      addTearDown(list.dispose);
      addTearDown(scroll.dispose);
      await pumpList(tester, build(list, scroll, false));
      expect(list.numberOfItems, 59);
      list.jumpToItem(index: 20, scrollController: scroll, alignment: 0);
      await tester.pumpAndSettle();
      // Child 20 is item 10.
      expect(scroll.offset, 1100);
    });
  });
}
