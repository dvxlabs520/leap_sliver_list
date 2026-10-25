import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

// Upstream issue #59: jumpToItem/animateToItem with CustomScrollView.center
// and CustomScrollView.anchor.
void main() {
  useDeterministicBudget();

  Widget build({
    required ListController listA,
    required ListController listB,
    required ScrollController scroll,
    required double anchor,
    required GlobalKey centerKey,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          height: 500,
          child: CustomScrollView(
            controller: scroll,
            center: centerKey,
            anchor: anchor,
            physics: const ClampingScrollPhysics(),
            slivers: [
              SuperSliverList.builder(
                listController: listA,
                itemCount: 30,
                itemBuilder: (_, i) => tile(i, 100, key: ValueKey("A$i")),
                extentPrecalculationPolicy: PreciseExtents(),
              ),
              SuperSliverList.builder(
                key: centerKey,
                listController: listB,
                itemCount: 30,
                itemBuilder: (_, i) =>
                    tile(i + 1000, 100, key: ValueKey("B$i")),
                extentPrecalculationPolicy: PreciseExtents(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Vertical position of a tile relative to the viewport top.
  double screenY(WidgetTester tester, String text) {
    final viewportTop = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    return tester.getTopLeft(find.text(text)).dy - viewportTop;
  }

  for (final anchor in [0.0, 0.5, 1.0]) {
    group("anchor $anchor", () {
      testWidgets("jumpToItem in the center list", (tester) async {
        final a = ListController();
        final b = ListController();
        final scroll = ScrollController();
        addTearDown(a.dispose);
        addTearDown(b.dispose);
        addTearDown(scroll.dispose);
        await pumpList(
          tester,
          build(
            listA: a,
            listB: b,
            scroll: scroll,
            anchor: anchor,
            centerKey: GlobalKey(),
          ),
        );
        b.jumpToItem(index: 8, scrollController: scroll, alignment: 0.0);
        await tester.pumpAndSettle();
        expect(find.text("Tile 1008"), findsOneWidget);
        expect(screenY(tester, "Tile 1008"), closeTo(0, 0.01));
      });

      testWidgets("jumpToItem in the list before the center", (tester) async {
        final a = ListController();
        final b = ListController();
        final scroll = ScrollController();
        addTearDown(a.dispose);
        addTearDown(b.dispose);
        addTearDown(scroll.dispose);
        await pumpList(
          tester,
          build(
            listA: a,
            listB: b,
            scroll: scroll,
            anchor: anchor,
            centerKey: GlobalKey(),
          ),
        );
        a.jumpToItem(index: 20, scrollController: scroll, alignment: 0.0);
        await tester.pumpAndSettle();
        expect(find.text("Tile 20"), findsOneWidget);
        expect(screenY(tester, "Tile 20"), closeTo(0, 0.01));
      });

      testWidgets("animateToItem in the list before the center", (
        tester,
      ) async {
        final a = ListController();
        final b = ListController();
        final scroll = ScrollController();
        addTearDown(a.dispose);
        addTearDown(b.dispose);
        addTearDown(scroll.dispose);
        await pumpList(
          tester,
          build(
            listA: a,
            listB: b,
            scroll: scroll,
            anchor: anchor,
            centerKey: GlobalKey(),
          ),
        );
        a.animateToItem(
          index: () => 12,
          scrollController: scroll,
          alignment: 0.0,
          duration: (_) => const Duration(milliseconds: 300),
          curve: (_) => Curves.linear,
        );
        await tester.pumpAndSettle();
        expect(find.text("Tile 12"), findsOneWidget);
        expect(screenY(tester, "Tile 12"), closeTo(0, 0.01));
      });
    });
  }
}
