import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

// Upstream issue #84: negative alignment.
void main() {
  useDeterministicBudget();

  testWidgets("negative alignment places item before the leading edge", (
    tester,
  ) async {
    final list = ListController();
    final scroll = ScrollController();
    addTearDown(list.dispose);
    addTearDown(scroll.dispose);
    await pumpList(
      tester,
      buildSingleList(
        itemCount: 40,
        height: (_) => 100,
        listController: list,
        scrollController: scroll,
      ),
    );
    // Item 10 leading edge is at 1000, viewport is 500, item is 100.
    // offset = 1000 - (500 - 100) * alignment
    list.jumpToItem(index: 10, scrollController: scroll, alignment: -0.3);
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(1000 + 0.3 * 400, 0.001));

    list.jumpToItem(index: 10, scrollController: scroll, alignment: 1.3);
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(1000 - 1.3 * 400, 0.001));
  });

  testWidgets("negative alignment with animateToItem", (tester) async {
    final list = ListController();
    final scroll = ScrollController();
    addTearDown(list.dispose);
    addTearDown(scroll.dispose);
    await pumpList(
      tester,
      buildSingleList(
        itemCount: 40,
        height: (_) => 100,
        listController: list,
        scrollController: scroll,
      ),
    );
    list.animateToItem(
      index: () => 10,
      scrollController: scroll,
      alignment: -0.3,
      duration: (_) => const Duration(milliseconds: 200),
      curve: (_) => Curves.linear,
    );
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(1000 + 0.3 * 400, 0.001));
  });
}
