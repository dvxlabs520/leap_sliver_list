import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

void main() {
  useDeterministicBudget();

  // 3 sections of 10 tiles (100 px) with a 50 px header, viewport of 500 px.
  Widget build(
    ScrollController scroll,
    StickyHeaderController? controller, {
    int sections = 3,
    List<ListController>? lists,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          height: 500,
          child: CustomScrollView(
            controller: scroll,
            physics: const ClampingScrollPhysics(),
            slivers: [
              for (var g = 0; g < sections; ++g)
                SuperStickyHeader(
                  controller: controller,
                  index: g,
                  header: SizedBox(height: 50, child: Text("Header $g")),
                  sliver: SuperSliverList.builder(
                    listController: lists?[g],
                    extentPrecalculationPolicy: PreciseExtents(),
                    itemCount: 10,
                    itemBuilder: (_, i) =>
                        SizedBox(height: 100, child: Text("G$g Tile $i")),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets("reports the header that is currently pinned", (tester) async {
    final scroll = ScrollController();
    final controller = StickyHeaderController();
    addTearDown(scroll.dispose);
    addTearDown(controller.dispose);
    await pumpList(tester, build(scroll, controller));

    // Nothing was scrolled, the first header is at the top.
    expect(controller.value, 0);

    scroll.jumpTo(600);
    await tester.pump();
    expect(controller.value, 0);

    // Section 1 starts at 1050 and its header is not yet at the top.
    scroll.jumpTo(1040);
    await tester.pump();
    expect(controller.value, 0);

    scroll.jumpTo(1050);
    await tester.pump();
    expect(controller.value, 1);

    scroll.jumpTo(1300);
    await tester.pump();
    expect(controller.value, 1);

    scroll.jumpTo(2150);
    await tester.pump();
    expect(controller.value, 2);

    scroll.jumpTo(0);
    await tester.pump();
    expect(controller.value, 0);
  });

  testWidgets("notifies only when the pinned header changes", (tester) async {
    final scroll = ScrollController();
    final controller = StickyHeaderController();
    addTearDown(scroll.dispose);
    addTearDown(controller.dispose);
    await pumpList(tester, build(scroll, controller));
    final values = <int?>[];
    controller.addListener(() => values.add(controller.value));

    for (final offset in [100.0, 400.0, 1100.0, 1200.0, 1500.0, 2200.0]) {
      scroll.jumpTo(offset);
      await tester.pump();
    }
    expect(values, [1, 2]);
  });

  testWidgets("follows jumps and animations to an item", (tester) async {
    final scroll = ScrollController();
    final controller = StickyHeaderController();
    final lists = [for (var i = 0; i < 3; ++i) ListController()];
    addTearDown(scroll.dispose);
    addTearDown(controller.dispose);
    for (final list in lists) {
      addTearDown(list.dispose);
    }
    await pumpList(tester, build(scroll, controller, lists: lists));

    lists[2].jumpToItem(index: 4, scrollController: scroll, alignment: 0.5);
    await tester.pump();
    expect(controller.value, 2);

    lists[1].animateToItem(
      index: () => 3,
      scrollController: scroll,
      alignment: 0,
      duration: (_) => const Duration(milliseconds: 300),
      curve: (_) => Curves.linear,
    );
    await tester.pumpAndSettle();
    expect(controller.value, 1);
  });

  testWidgets("removed headers are forgotten", (tester) async {
    final scroll = ScrollController();
    final controller = StickyHeaderController();
    addTearDown(scroll.dispose);
    addTearDown(controller.dispose);
    await pumpList(tester, build(scroll, controller));
    scroll.jumpTo(2200);
    await tester.pump();
    expect(controller.value, 2);

    await pumpList(tester, build(scroll, controller, sections: 2));
    await tester.pump();
    expect(controller.value, 1);
  });

  testWidgets("works without a controller", (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pumpList(tester, build(scroll, null));
    scroll.jumpTo(1300);
    await tester.pump();
    expect(find.text("Header 1"), findsOneWidget);
  });
}
