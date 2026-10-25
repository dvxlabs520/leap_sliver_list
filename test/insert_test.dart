import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

// Upstream issue #71: no way to keep the scroll position when items are
// prepended to the list.
void main() {
  useDeterministicBudget();

  Future<(ListController, ScrollController, ValueNotifier<int>)> pump(
    WidgetTester tester, {
    bool separated = false,
    double itemHeight = 100,
  }) async {
    final list = ListController();
    final scroll = ScrollController();
    final count = ValueNotifier<int>(100);
    addTearDown(list.dispose);
    addTearDown(scroll.dispose);
    addTearDown(count.dispose);
    await pumpList(
      tester,
      ValueListenableBuilder<int>(
        valueListenable: count,
        builder: (context, count, _) => buildSingleList(
          itemCount: count,
          height: (_) => itemHeight,
          separated: separated,
          separatorHeight: 0,
          listController: list,
          scrollController: scroll,
        ),
      ),
    );
    scroll.jumpTo(1000);
    await tester.pumpAndSettle();
    return (list, scroll, count);
  }

  double tileTop(WidgetTester tester, int index) {
    return tester.getTopLeft(find.text("Tile $index")).dy -
        tester.getTopLeft(find.byType(CustomScrollView)).dy;
  }

  testWidgets("addItem without preserveScrollPosition keeps the offset", (
    tester,
  ) async {
    final (list, scroll, count) = await pump(tester);
    count.value = 105;
    list.addItem(0, count: 5);
    await tester.pumpAndSettle();
    expect(list.numberOfItems, 105);
    expect(scroll.offset, 1000);
    expect(tileTop(tester, 10), closeTo(0, 0.01));
  });

  testWidgets("prepending with preserveScrollPosition keeps visible items", (
    tester,
  ) async {
    final (list, scroll, count) = await pump(tester);
    expect(tileTop(tester, 10), closeTo(0, 0.01));
    count.value = 105;
    list.addItem(0, count: 5, preserveScrollPosition: true);
    await tester.pumpAndSettle();
    expect(list.numberOfItems, 105);
    expect(scroll.offset, 1500);
    // The item that was on top is now item 15.
    expect(tileTop(tester, 15), closeTo(0, 0.01));
  });

  testWidgets("inserting below the viewport does not move the offset", (
    tester,
  ) async {
    final (list, scroll, count) = await pump(tester);
    count.value = 103;
    list.addItem(50, count: 3, preserveScrollPosition: true);
    await tester.pumpAndSettle();
    expect(scroll.offset, 1000);
    expect(tileTop(tester, 10), closeTo(0, 0.01));
  });

  testWidgets("inserting in the middle of the viewport does not jump", (
    tester,
  ) async {
    final (list, scroll, count) = await pump(tester);
    // Item 12 is in the viewport; items above it are unaffected.
    count.value = 102;
    list.addItem(12, count: 2, preserveScrollPosition: true);
    await tester.pumpAndSettle();
    expect(scroll.offset, 1000);
    expect(tileTop(tester, 10), closeTo(0, 0.01));
  });

  testWidgets("estimates differing from real extents", (tester) async {
    final (list, scroll, count) = await pump(tester, itemHeight: 50);
    scroll.jumpTo(500);
    await tester.pumpAndSettle();
    expect(tileTop(tester, 10), closeTo(0, 0.01));
    count.value = 120;
    list.addItem(0, count: 20, preserveScrollPosition: true);
    await tester.pumpAndSettle();
    expect(tileTop(tester, 30), closeTo(0, 0.01));
    expect(scroll.offset, 1500);
  });

  testWidgets("works with separated lists", (tester) async {
    final (list, scroll, count) = await pump(tester, separated: true);
    // Separators have zero height, only items count.
    scroll.jumpTo(1000);
    await tester.pumpAndSettle();
    count.value = 104;
    list.addItem(0, count: 4, preserveScrollPosition: true);
    await tester.pumpAndSettle();
    expect(list.numberOfItems, 104);
    expect(scroll.offset, 1400);
    expect(tileTop(tester, 14), closeTo(0, 0.01));
  });
}
