import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

void main() {
  useDeterministicBudget();

  // 3 sections of 10 tiles (100 px) with a 50 px header, viewport of 500 px.
  Future<(ListController, ScrollController)> pump(
    WidgetTester tester, {
    bool precise = true,
    bool separated = false,
  }) async {
    final scroll = ScrollController();
    final list = ListController();
    addTearDown(scroll.dispose);
    addTearDown(list.dispose);
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
                for (var g = 0; g < 3; ++g)
                  SuperStickyHeader(
                    header: SizedBox(height: 50, child: Text("Header $g")),
                    sliver: separated
                        ? SuperSliverList.separated(
                            listController: g == 1 ? list : null,
                            extentPrecalculationPolicy: precise
                                ? PreciseExtents()
                                : null,
                            itemCount: 10,
                            itemBuilder: (_, i) => SizedBox(
                              height: 100,
                              child: Text("G$g Tile $i"),
                            ),
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                          )
                        : SuperSliverList.builder(
                            listController: g == 1 ? list : null,
                            extentPrecalculationPolicy: precise
                                ? PreciseExtents()
                                : null,
                            itemCount: 10,
                            itemBuilder: (_, i) => SizedBox(
                              height: 100,
                              child: Text("G$g Tile $i"),
                            ),
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

  double? top(WidgetTester tester, String text) {
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) {
      return null;
    }
    return tester.getTopLeft(finder).dy -
        tester.getTopLeft(find.byType(CustomScrollView)).dy;
  }

  testWidgets("header stays pinned and is pushed out by the next one", (
    tester,
  ) async {
    final (_, scroll) = await pump(tester);
    expect(top(tester, "Header 0"), 0);
    scroll.jumpTo(300);
    await tester.pump();
    expect(top(tester, "Header 0"), 0);
    // Section 0 is 1050 px long, section 1 starts at 1050. The next header
    // pushes the previous one out.
    scroll.jumpTo(1000);
    await tester.pump();
    expect(top(tester, "Header 0"), 0);
    expect(top(tester, "Header 1"), 50);
    scroll.jumpTo(1030);
    await tester.pump();
    expect(top(tester, "Header 0"), -30);
    expect(top(tester, "Header 1"), 20);
    scroll.jumpTo(1070);
    await tester.pump();
    expect(top(tester, "Header 1"), 0);
    expect(find.text("Header 0"), findsNothing);
    expect(top(tester, "Header 1"), 0);
  });

  for (final precise in [true, false]) {
    final suffix = precise ? "precise" : "estimated";

    testWidgets("jumpToItem aligns below the header ($suffix)", (tester) async {
      final (list, scroll) = await pump(tester, precise: precise);
      // Visible area below the header: 450 px, tiles are 100 px.
      for (final (alignment, expected) in [
        (0.0, 50.0),
        (0.5, 50.0 + 175),
        (1.0, 50.0 + 350),
      ]) {
        list.jumpToItem(
          index: 5,
          scrollController: scroll,
          alignment: alignment,
        );
        await tester.pumpAndSettle();
        expect(
          top(tester, "G1 Tile 5"),
          closeTo(expected, 0.01),
          reason: "alignment $alignment",
        );
      }
    });

    testWidgets("animateToItem aligns below the header ($suffix)", (
      tester,
    ) async {
      final (list, scroll) = await pump(tester, precise: precise);
      final animation = list.animateToItem(
        index: () => 8,
        scrollController: scroll,
        alignment: 1.0,
        duration: (_) => const Duration(milliseconds: 300),
        curve: (_) => Curves.easeOut,
      );
      await tester.pumpAndSettle();
      expect(animation.isCompleted, isTrue);
      expect(top(tester, "G1 Tile 8"), closeTo(400, 0.01));
    });
  }

  testWidgets("works with separated lists", (tester) async {
    final (list, scroll) = await pump(tester, separated: true);
    list.jumpToItem(index: 4, scrollController: scroll, alignment: 0.0);
    await tester.pumpAndSettle();
    expect(top(tester, "G1 Tile 4"), closeTo(50, 0.01));
    list.jumpToItem(index: 4, scrollController: scroll, alignment: 1.0);
    await tester.pumpAndSettle();
    expect(top(tester, "G1 Tile 4"), closeTo(400, 0.01));
  });

  testWidgets("an extra obstruction is added to the header", (tester) async {
    final (list, scroll) = await pump(tester);
    // Something else covers the bottom 40 px of the viewport.
    list.jumpToItem(
      index: 5,
      scrollController: scroll,
      alignment: 1.0,
      obstruction: const ChildObstructionExtent(leading: 0, trailing: 40),
    );
    await tester.pumpAndSettle();
    expect(top(tester, "G1 Tile 5"), closeTo(360, 0.01));
  });
}
