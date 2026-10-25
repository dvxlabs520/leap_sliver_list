import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

void main() {
  useDeterministicBudget();

  double heightOf(int i) => 40.0 + (i * 37 % 60);

  double topOf(WidgetTester tester, int index) =>
      tester.getTopLeft(find.byKey(ValueKey<int>(index))).dy -
      tester.getTopLeft(find.byType(CustomScrollView)).dy;

  Future<(ScrollController, ListController)> pump(
    WidgetTester tester, {
    bool precise = true,
  }) async {
    final controller = ScrollController();
    final list = ListController();
    addTearDown(controller.dispose);
    addTearDown(list.dispose);
    await pumpList(
      tester,
      buildSingleList(
        itemCount: 200,
        height: heightOf,
        listController: list,
        scrollController: controller,
        precise: precise,
      ),
    );
    return (controller, list);
  }

  for (final precise in [true, false]) {
    final suffix = precise ? "precise" : "estimated";

    testWidgets("jumpToItem with alignmentOffset at leading edge ($suffix)", (
      tester,
    ) async {
      final (controller, list) = await pump(tester, precise: precise);
      list.jumpToItem(
        index: 120,
        scrollController: controller,
        alignment: 0.0,
        alignmentOffset: 24,
      );
      await tester.pumpAndSettle();
      expect(topOf(tester, 120), moreOrLessEquals(24));
    });

    testWidgets("jumpToItem with negative alignmentOffset in the middle "
        "($suffix)", (tester) async {
      final (controller, list) = await pump(tester, precise: precise);
      list.jumpToItem(
        index: 150,
        scrollController: controller,
        alignment: 0.5,
        alignmentOffset: -30,
      );
      await tester.pumpAndSettle();
      final height = heightOf(150);
      expect(topOf(tester, 150), moreOrLessEquals((500 - height) / 2 - 30));
    });

    testWidgets("jumpToItem with alignmentOffset at trailing edge ($suffix)", (
      tester,
    ) async {
      final (controller, list) = await pump(tester, precise: precise);
      list.jumpToItem(
        index: 90,
        scrollController: controller,
        alignment: 1.0,
        alignmentOffset: -16,
      );
      await tester.pumpAndSettle();
      expect(topOf(tester, 90), moreOrLessEquals(500 - heightOf(90) - 16));
    });
  }

  testWidgets("animateToItem honors alignmentOffset", (tester) async {
    final (controller, list) = await pump(tester);
    final animation = list.animateToItem(
      index: () => 100,
      scrollController: controller,
      alignment: 0.0,
      alignmentOffset: 40,
      duration: (_) => const Duration(milliseconds: 300),
      curve: (_) => Curves.linear,
    );
    await tester.pumpAndSettle();
    expect(animation.isCompleted, isTrue);
    expect(animation.isCanceled, isFalse);
    expect(topOf(tester, 100), moreOrLessEquals(40));
  });

  testWidgets("getOffsetToReveal shifts by alignmentOffset", (tester) async {
    final (_, list) = await pump(tester);
    final base = list.getOffsetToReveal(60, 0.0);
    final shifted = list.getOffsetToReveal(60, 0.0, alignmentOffset: 12);
    expect(shifted, moreOrLessEquals(base - 12));
  });
}
