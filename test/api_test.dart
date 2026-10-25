import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

void main() {
  useDeterministicBudget();

  group("public offset API", () {
    testWidgets("offsetForIndex returns leading offset of an item", (
      tester,
    ) async {
      final list = ListController();
      final scroll = ScrollController();
      addTearDown(list.dispose);
      addTearDown(scroll.dispose);
      await pumpList(
        tester,
        buildSingleList(
          itemCount: 20,
          height: (i) => 100.0 + i * 10,
          listController: list,
          scrollController: scroll,
        ),
      );
      expect(list.offsetForIndex(0), 0);
      expect(list.offsetForIndex(1), 100);
      expect(list.offsetForIndex(3), 100 + 110 + 120);
    });

    testWidgets("getOffsetToReveal is public and honors alignment", (
      tester,
    ) async {
      final list = ListController();
      final scroll = ScrollController();
      addTearDown(list.dispose);
      addTearDown(scroll.dispose);
      await pumpList(
        tester,
        buildSingleList(
          itemCount: 20,
          height: (_) => 100,
          listController: list,
          scrollController: scroll,
        ),
      );
      // Item 10 starts at 1000. Viewport is 500 high.
      expect(list.getOffsetToReveal(10, 0.0), 1000);
      expect(list.getOffsetToReveal(10, 1.0), 1000 - 400);
      expect(list.getOffsetToReveal(10, 0.5), 1000 - 200);
    });
  });
}
