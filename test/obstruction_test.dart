import "package:flutter/widgets.dart";
import "package:flutter_sticky_header/flutter_sticky_header.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

// Upstream issue #85: jumpToItem did not account for sticky headers that
// wrap the list (flutter_sticky_header's SliverStickyHeader).
void main() {
  useDeterministicBudget();

  Future<(ListController, ScrollController)> pump(WidgetTester tester) async {
    final list = ListController();
    final scroll = ScrollController();
    addTearDown(list.dispose);
    addTearDown(scroll.dispose);
    await pumpList(
      tester,
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            height: 500,
            child: CustomScrollView(
              controller: scroll,
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverStickyHeader(
                  header: const SizedBox(height: 50, child: Text("Header")),
                  sliver: SuperSliverList.builder(
                    listController: list,
                    extentPrecalculationPolicy: PreciseExtents(),
                    itemCount: 100,
                    itemBuilder: (_, i) => tile(i, 100),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return (list, scroll);
  }

  double tileTop(WidgetTester tester, int index) {
    return tester.getTopLeft(find.text("Tile $index")).dy -
        tester.getTopLeft(find.byType(CustomScrollView)).dy;
  }

  const header = ChildObstructionExtent(leading: 50, trailing: 0);

  testWidgets("without obstruction the item hides below the header", (
    tester,
  ) async {
    final (list, scroll) = await pump(tester);
    list.jumpToItem(index: 10, scrollController: scroll, alignment: 0);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tileTop(tester, 10), closeTo(0, 0.01));
  });

  testWidgets("jumpToItem with obstruction", (tester) async {
    final (list, scroll) = await pump(tester);
    list.jumpToItem(
      index: 10,
      scrollController: scroll,
      alignment: 0,
      obstruction: header,
    );
    await tester.pumpAndSettle();
    expect(tileTop(tester, 10), closeTo(50, 0.01));
  });

  testWidgets("animateToItem with obstruction", (tester) async {
    final (list, scroll) = await pump(tester);
    final animation = list.animateToItem(
      index: () => 30,
      scrollController: scroll,
      alignment: 0,
      obstruction: header,
      duration: (_) => const Duration(milliseconds: 300),
      curve: (_) => Curves.linear,
    );
    await tester.pumpAndSettle();
    expect(animation.isCompleted, isTrue);
    expect(tileTop(tester, 30), closeTo(50, 0.01));
  });

  testWidgets("getOffsetToReveal with obstruction", (tester) async {
    final (list, _) = await pump(tester);
    final plain = list.getOffsetToReveal(10, 0);
    expect(list.getOffsetToReveal(10, 0, obstruction: header), plain - 50);
    // Trailing obstruction applies at the trailing edge.
    const footer = ChildObstructionExtent(leading: 0, trailing: 40);
    expect(
      list.getOffsetToReveal(10, 1, obstruction: footer),
      list.getOffsetToReveal(10, 1) + 40,
    );
  });
}
