import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

void main() {
  useDeterministicBudget();

  for (final precise in [true, false]) {
    final suffix = precise ? "precise" : "estimated";

    group("stickToEnd ($suffix)", () {
      late ScrollController controller;
      late ListController list;
      var lastHeight = 50.0;

      setUp(() {
        controller = ScrollController();
        list = ListController();
        lastHeight = 50.0;
      });
      tearDown(() {
        controller.dispose();
        list.dispose();
      });

      Widget build(int count, {bool stickToEnd = true}) => buildSingleList(
        itemCount: count,
        height: (i) => i == count - 1 ? lastHeight : 50,
        listController: list,
        scrollController: controller,
        precise: precise,
        stickToEnd: stickToEnd,
      );

      void expectAtEnd() => expect(
        controller.offset,
        moreOrLessEquals(controller.position.maxScrollExtent),
      );

      testWidgets("starts at the end", (tester) async {
        await pumpList(tester, build(30));
        expectAtEnd();
        expect(controller.offset, greaterThan(0));
      });

      testWidgets("follows appended items", (tester) async {
        await pumpList(tester, build(30));
        await pumpList(tester, build(33));
        expectAtEnd();
        await pumpList(tester, build(50));
        expectAtEnd();
        expect(find.byKey(const ValueKey<int>(49)), findsOneWidget);
      });

      testWidgets("follows a growing last item", (tester) async {
        await pumpList(tester, build(30));
        lastHeight = 300;
        await pumpList(tester, build(30));
        expectAtEnd();
        expect(controller.position.maxScrollExtent, 1000 + 250);
      });

      testWidgets("leaves the position alone when scrolled away", (
        tester,
      ) async {
        await pumpList(tester, build(30));
        controller.jumpTo(200);
        await tester.pumpAndSettle();
        await pumpList(tester, build(40));
        expect(controller.offset, 200);
      });

      testWidgets("follows again once the user is back at the end", (
        tester,
      ) async {
        await pumpList(tester, build(30));
        controller.jumpTo(200);
        await tester.pumpAndSettle();
        await pumpList(tester, build(40));
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        await pumpList(tester, build(45));
        expectAtEnd();
      });

      testWidgets("is off by default", (tester) async {
        await pumpList(tester, build(30, stickToEnd: false));
        expect(controller.offset, 0);
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final before = controller.offset;
        await pumpList(tester, build(33, stickToEnd: false));
        expect(controller.offset, before);
      });
    });
  }

  testWidgets("reverse chat keeps position when inserting at index 0", (
    tester,
  ) async {
    final controller = ScrollController();
    final list = ListController();
    addTearDown(controller.dispose);
    addTearDown(list.dispose);
    var count = 40;
    Widget build() => buildSingleList(
      itemCount: count,
      height: (i) => 50,
      listController: list,
      scrollController: controller,
      reverse: true,
    );
    await pumpList(tester, build());
    controller.jumpTo(300);
    await tester.pumpAndSettle();
    list.addItem(0, preserveScrollPosition: true);
    count += 1;
    await pumpList(tester, build());
    expect(controller.offset, 350);

    // At the newest message the list stays there (offset 0 is the end).
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    list.addItem(0);
    count += 1;
    await pumpList(tester, build());
    expect(controller.offset, 0);
  });
}
