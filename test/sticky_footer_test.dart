import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

void main() {
  useDeterministicBudget();

  // Viewport of 500 px; footers are 50 px, tiles 100 px.
  Widget build(
    ScrollController scroll, {
    List<int> sections = const [10],
    List<ListController>? lists,
    VoidCallback? onFooterTap,
    bool withHeaders = false,
    AxisDirection? direction,
    Axis axis = Axis.vertical,
  }) {
    Widget footer(int g) => SizedBox(
      height: 50,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onFooterTap,
        child: Text("Footer $g", key: ValueKey("footer$g")),
      ),
    );
    Widget list(int g) => SuperSliverList.builder(
      listController: lists?[g],
      extentPrecalculationPolicy: PreciseExtents(),
      itemCount: sections[g],
      itemBuilder: (_, i) => SizedBox(
        key: ValueKey("tile$g-$i"),
        height: 100,
        child: Text("G$g Tile $i"),
      ),
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          height: axis == Axis.vertical ? 500 : 100,
          width: axis == Axis.vertical ? 300 : 500,
          child: CustomScrollView(
            controller: scroll,
            scrollDirection: axis,
            reverse: direction == AxisDirection.up,
            physics: const ClampingScrollPhysics(),
            slivers: [
              for (var g = 0; g < sections.length; ++g)
                if (withHeaders)
                  SuperStickyHeader(
                    header: SizedBox(height: 50, child: Text("Header $g")),
                    sliver: SuperStickyFooter(
                      footer: footer(g),
                      sliver: list(g),
                    ),
                  )
                else
                  SuperStickyFooter(footer: footer(g), sliver: list(g)),
            ],
          ),
        ),
      ),
    );
  }

  double footerTop(WidgetTester tester, int g) =>
      tester.getTopLeft(find.byKey(ValueKey("footer$g"))).dy;

  testWidgets("sticks to the bottom while the list is long", (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pumpList(tester, build(scroll));
    final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    for (final offset in [0.0, 300.0, 549.0]) {
      scroll.jumpTo(offset);
      await tester.pump();
      expect(footerTop(tester, 0) - top, 450, reason: "offset $offset");
    }
  });

  testWidgets("sits right after a short list", (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pumpList(tester, build(scroll, sections: const [2]));
    final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    expect(footerTop(tester, 0) - top, 200);
    expect(scroll.position.maxScrollExtent, 0);
  });

  testWidgets("scrolls away with the end of the list", (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    // Two sections: [3 tiles + footer] then [10 tiles + footer].
    await pumpList(tester, build(scroll, sections: const [3, 10]));
    final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;

    // Section 0 is 300 px of tiles: its footer follows them.
    expect(footerTop(tester, 0) - top, 300);
    // Section 1 begins right after it, its footer is pinned at the bottom.
    expect(footerTop(tester, 1) - top, 450);

    scroll.jumpTo(100);
    await tester.pump();
    expect(footerTop(tester, 0) - top, 200);

    scroll.jumpTo(300);
    await tester.pump();
    expect(footerTop(tester, 0) - top, 0);

    scroll.jumpTo(330);
    await tester.pump();
    expect(footerTop(tester, 0) - top, -30);
  });

  testWidgets("footer receives taps, tiles below it do not", (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var taps = 0;
    await pumpList(tester, build(scroll, onFooterTap: () => taps++));
    await tester.tap(find.byKey(const ValueKey("footer0")));
    expect(taps, 1);
    // The tile behind the footer is not hit.
    expect(
      tester
          .hitTestOnBinding(
            tester.getCenter(find.byKey(const ValueKey("footer0"))),
          )
          .path
          .any(
            (e) =>
                e.target is RenderParagraph &&
                (e.target as RenderParagraph).text.toPlainText() == "G0 Tile 4",
          ),
      isFalse,
    );
  });

  testWidgets("jumpToItem keeps the item clear of the footer", (tester) async {
    final scroll = ScrollController();
    final list = ListController();
    addTearDown(scroll.dispose);
    await pumpList(tester, build(scroll, lists: [list]));
    final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;

    list.jumpToItem(index: 5, scrollController: scroll, alignment: 1.0);
    await tester.pump();
    final tile = tester.getRect(find.byKey(const ValueKey("tile0-5")));
    // The bottom of the item is aligned with the top of the footer.
    expect(tile.bottom - top, closeTo(450, 0.01));
    expect(footerTop(tester, 0) - top, 450);

    list.jumpToItem(index: 2, scrollController: scroll, alignment: 0.0);
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey("tile0-2"))).dy - top,
      closeTo(0, 0.01),
    );
  });

  testWidgets("animateToItem keeps the item clear of the footer", (
    tester,
  ) async {
    final scroll = ScrollController();
    final list = ListController();
    addTearDown(scroll.dispose);
    await pumpList(tester, build(scroll, lists: [list]));
    final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;

    list.animateToItem(
      index: 7,
      scrollController: scroll,
      alignment: (_) => 1.0,
      duration: (_) => const Duration(milliseconds: 300),
      curve: (_) => Curves.linear,
    );
    await tester.pumpAndSettle();
    final tile = tester.getRect(find.byKey(const ValueKey("tile0-7")));
    expect(tile.bottom - top, closeTo(450, 0.01));
  });

  testWidgets("composes with sticky headers", (tester) async {
    final scroll = ScrollController();
    final list = ListController();
    addTearDown(scroll.dispose);
    await pumpList(tester, build(scroll, withHeaders: true, lists: [list]));
    final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    scroll.jumpTo(300);
    await tester.pump();
    expect(tester.getTopLeft(find.text("Header 0")).dy - top, 0);
    expect(footerTop(tester, 0) - top, 450);

    // Aligned to the trailing edge, the item sits between the header and
    // the footer.
    list.jumpToItem(index: 5, scrollController: scroll, alignment: 1.0);
    await tester.pump();
    final tile = tester.getRect(find.byKey(const ValueKey("tile0-5")));
    expect(tile.bottom - top, closeTo(450, 0.01));
  });

  testWidgets("works on a horizontal list", (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 500,
            height: 100,
            child: CustomScrollView(
              controller: scroll,
              scrollDirection: Axis.horizontal,
              slivers: [
                SuperStickyFooter(
                  footer: const SizedBox(
                    width: 50,
                    child: Text("Footer", key: ValueKey("footer")),
                  ),
                  sliver: SuperSliverList.builder(
                    extentPrecalculationPolicy: PreciseExtents(),
                    itemCount: 10,
                    itemBuilder: (_, i) =>
                        SizedBox(width: 100, child: Text("T$i")),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final left = tester.getTopLeft(find.byType(CustomScrollView)).dx;
    scroll.jumpTo(200);
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey("footer"))).dx - left,
      450,
    );
  });

  testWidgets("works in a reversed list", (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pumpList(tester, build(scroll, direction: AxisDirection.up));
    final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    // The trailing edge is the top of the viewport in a reversed list.
    scroll.jumpTo(200);
    await tester.pump();
    expect(footerTop(tester, 0) - top, 0);
  });
}
