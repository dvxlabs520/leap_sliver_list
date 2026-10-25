import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

void main() {
  useDeterministicBudget();

  // Item i is 50 + (i % 3) * 10 px high, so the rows of a 3 column grid are
  // 70 px high.
  double heightOf(int i) => 50.0 + (i % 3) * 10;

  Widget build({
    required ScrollController scroll,
    GridController? controller,
    int crossAxisCount = 3,
    int itemCount = 10,
    double mainAxisSpacing = 0,
    double crossAxisSpacing = 0,
    double? maxCrossAxisExtent,
    double Function(int)? height,
    double width = 300,
    double viewport = 500,
    bool precise = true,
  }) {
    Widget item(BuildContext _, int i) => SizedBox(
      key: ValueKey<int>(i),
      height: (height ?? heightOf)(i),
      child: Text("Cell $i"),
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: width,
          height: viewport,
          child: CustomScrollView(
            controller: scroll,
            physics: const ClampingScrollPhysics(),
            slivers: [
              if (maxCrossAxisExtent != null)
                SuperSliverGrid.extent(
                  maxCrossAxisExtent: maxCrossAxisExtent,
                  controller: controller,
                  itemCount: itemCount,
                  mainAxisSpacing: mainAxisSpacing,
                  crossAxisSpacing: crossAxisSpacing,
                  extentPrecalculationPolicy: precise ? PreciseExtents() : null,
                  itemBuilder: item,
                )
              else
                SuperSliverGrid.builder(
                  crossAxisCount: crossAxisCount,
                  controller: controller,
                  itemCount: itemCount,
                  mainAxisSpacing: mainAxisSpacing,
                  crossAxisSpacing: crossAxisSpacing,
                  extentPrecalculationPolicy: precise ? PreciseExtents() : null,
                  itemBuilder: item,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Rect rectOf(WidgetTester tester, int i) {
    final origin = tester.getTopLeft(find.byType(CustomScrollView));
    return tester.getRect(find.byKey(ValueKey<int>(i))).shift(-origin);
  }

  testWidgets("lays out items in columns", (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pumpList(tester, build(scroll: scroll));
    expect(rectOf(tester, 0), const Rect.fromLTWH(0, 0, 100, 50));
    expect(rectOf(tester, 1), const Rect.fromLTWH(100, 0, 100, 60));
    expect(rectOf(tester, 2), const Rect.fromLTWH(200, 0, 100, 70));
    // The second row starts below the tallest cell of the first one.
    expect(rectOf(tester, 3), const Rect.fromLTWH(0, 70, 100, 50));
    expect(rectOf(tester, 5), const Rect.fromLTWH(200, 70, 100, 70));
  });

  testWidgets("the last row may be incomplete", (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pumpList(tester, build(scroll: scroll));
    // 10 items: rows of 3, 3, 3 and 1.
    expect(rectOf(tester, 9), const Rect.fromLTWH(0, 210, 100, 50));
    expect(scroll.position.maxScrollExtent, 0);
    expect(find.byKey(const ValueKey<int>(10)), findsNothing);
  });

  testWidgets("spacing", (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pumpList(
      tester,
      build(scroll: scroll, mainAxisSpacing: 8, crossAxisSpacing: 10),
    );
    // (300 - 2 * 10) / 3 = 93.33 px per column.
    const width = 280 / 3;
    expect(rectOf(tester, 0).width, closeTo(width, 0.001));
    expect(rectOf(tester, 1).left, closeTo(width + 10, 0.001));
    expect(rectOf(tester, 2).left, closeTo(2 * (width + 10), 0.001));
    expect(rectOf(tester, 2).right, closeTo(300, 0.001));
    // Rows are 70 px high plus 8 px of spacing.
    expect(rectOf(tester, 3).top, 78);
    expect(rectOf(tester, 6).top, 156);
  });

  testWidgets("maxCrossAxisExtent decides the number of columns", (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pumpList(tester, build(scroll: scroll, maxCrossAxisExtent: 120));
    // ceil(300 / 120) = 3 columns of 100 px.
    expect(rectOf(tester, 2), const Rect.fromLTWH(200, 0, 100, 70));

    await pumpList(
      tester,
      build(scroll: scroll, maxCrossAxisExtent: 120, width: 500),
    );
    // ceil(500 / 120) = 5 columns.
    expect(rectOf(tester, 4).left, closeTo(400, 0.001));
    expect(rectOf(tester, 5).left, 0);
    expect(rectOf(tester, 5).top, greaterThan(0));
  });

  testWidgets("only builds what is visible", (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pumpList(
      tester,
      build(
        scroll: scroll,
        itemCount: 30000,
        crossAxisCount: 3,
        precise: false,
      ),
    );
    expect(find.byType(SizedBox).evaluate().length, lessThan(100));
    scroll.jumpTo(100000);
    await tester.pump();
    expect(find.byType(SizedBox).evaluate().length, lessThan(100));
  });

  testWidgets("reports the visible items", (tester) async {
    final scroll = ScrollController();
    final controller = GridController();
    addTearDown(scroll.dispose);
    addTearDown(controller.dispose);
    await pumpList(
      tester,
      build(scroll: scroll, controller: controller, itemCount: 300),
    );
    expect(controller.isAttached, isTrue);
    expect(controller.crossAxisCount, 3);
    expect(controller.firstVisibleIndex, 0);
    // 500 px show 7 rows of 70 px and part of the eighth.
    expect(controller.lastVisibleIndex, 23);

    scroll.jumpTo(70 * 10);
    await tester.pump();
    expect(controller.firstVisibleIndex, 30);
    expect(controller.rowOf(31), 10);
  });

  testWidgets("jumpToItem aligns the row of the item", (tester) async {
    final scroll = ScrollController();
    final controller = GridController();
    addTearDown(scroll.dispose);
    addTearDown(controller.dispose);
    await pumpList(
      tester,
      build(scroll: scroll, controller: controller, itemCount: 300),
    );
    controller.jumpToItem(index: 100, scrollController: scroll, alignment: 0.0);
    await tester.pump();
    // Item 100 is the second one of row 33.
    expect(rectOf(tester, 100).top, closeTo(0, 0.01));
    expect(rectOf(tester, 100).left, 100);
    expect(scroll.offset, closeTo(33 * 70, 0.01));

    controller.jumpToItem(index: 200, scrollController: scroll, alignment: 1.0);
    await tester.pump();
    // Row 66 ends at the bottom of the viewport.
    expect(rectOf(tester, 200).bottom, closeTo(500, 0.01));
    expect(rectOf(tester, 198).bottom, closeTo(480, 0.01));
  });

  testWidgets("animateToItem scrolls to the row of the item", (tester) async {
    final scroll = ScrollController();
    final controller = GridController();
    addTearDown(scroll.dispose);
    addTearDown(controller.dispose);
    await pumpList(
      tester,
      build(scroll: scroll, controller: controller, itemCount: 300),
    );
    controller.animateToItem(
      index: () => 150,
      scrollController: scroll,
      alignment: 0.0,
      duration: (_) => const Duration(milliseconds: 300),
      curve: (_) => Curves.easeInOut,
    );
    await tester.pumpAndSettle();
    expect(rectOf(tester, 150).top, closeTo(0, 0.01));
    expect(scroll.offset, closeTo(50 * 70, 0.01));
  });

  testWidgets("rows follow the tallest cell", (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    // Only the cell 4 is tall.
    double height(int i) => i == 4 ? 200 : 40;
    await pumpList(tester, build(scroll: scroll, height: height));
    expect(rectOf(tester, 3).top, 40);
    expect(rectOf(tester, 4).height, 200);
    expect(rectOf(tester, 6).top, 240);
  });

  testWidgets("changing the number of columns relays out the grid", (
    tester,
  ) async {
    final scroll = ScrollController();
    final controller = GridController();
    addTearDown(scroll.dispose);
    addTearDown(controller.dispose);
    await pumpList(
      tester,
      build(scroll: scroll, controller: controller, itemCount: 12),
    );
    expect(rectOf(tester, 3).top, 70);

    await pumpList(
      tester,
      build(
        scroll: scroll,
        controller: controller,
        itemCount: 12,
        crossAxisCount: 2,
      ),
    );
    expect(controller.crossAxisCount, 2);
    expect(rectOf(tester, 1), const Rect.fromLTWH(150, 0, 150, 60));
    // Rows are now pairs: (0, 1) is 60 px high, (2, 3) 70 px.
    expect(rectOf(tester, 2).top, 60);
    expect(rectOf(tester, 4).top, 130);
    controller.jumpToItem(index: 11, scrollController: scroll, alignment: 0.0);
    await tester.pump();
    expect(controller.lastVisibleIndex, 11);
  });

  testWidgets("changing the number of columns forgets measured extents", (
    tester,
  ) async {
    final scroll = ScrollController();
    final controller = GridController();
    addTearDown(scroll.dispose);
    addTearDown(controller.dispose);
    Widget grid(int columns) => build(
      scroll: scroll,
      controller: controller,
      itemCount: 3000,
      crossAxisCount: columns,
      precise: false,
    );
    await pumpList(tester, grid(3));
    for (var i = 0; i < 20; ++i) {
      scroll.jumpTo(scroll.offset + 450);
      await tester.pump();
    }
    final measured =
        controller.rows.numberOfItems -
        controller.rows.numberOfItemsWithEstimatedExtent;
    expect(measured, greaterThan(20));

    await pumpList(tester, grid(2));
    await tester.pump();
    // Only rows around the viewport have a measured extent again.
    final measuredNow =
        controller.rows.numberOfItems -
        controller.rows.numberOfItemsWithEstimatedExtent;
    expect(controller.rows.numberOfItems, 1500);
    expect(measuredNow, lessThan(30));
  });

  testWidgets("works with sticky headers", (tester) async {
    final scroll = ScrollController();
    final controller = GridController();
    addTearDown(scroll.dispose);
    addTearDown(controller.dispose);
    await pumpList(
      tester,
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            height: 500,
            child: CustomScrollView(
              controller: scroll,
              physics: const ClampingScrollPhysics(),
              slivers: [
                SuperStickyHeader(
                  header: const SizedBox(height: 50, child: Text("Header")),
                  sliver: SuperSliverGrid.builder(
                    controller: controller,
                    crossAxisCount: 3,
                    itemCount: 300,
                    extentPrecalculationPolicy: PreciseExtents(),
                    itemBuilder: (_, i) => SizedBox(
                      key: ValueKey<int>(i),
                      height: heightOf(i),
                      child: Text("Cell $i"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.jumpToItem(index: 90, scrollController: scroll, alignment: 0.0);
    await tester.pump();
    // The row is aligned right under the pinned header.
    expect(rectOf(tester, 90).top, closeTo(50, 0.01));
  });
}
