import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

/// Precalculates all extents so that offsets are exact in tests.
class PreciseExtents extends ExtentPrecalculationPolicy {
  @override
  bool shouldPrecalculateExtents(_) => true;
}

/// Deterministic layout budget (does not depend on wall clock).
class CountingBudget extends SuperSliverListLayoutBudget {
  double _count = 0;
  static const limit = 8;

  @override
  void reset() => _count = 0;

  @override
  void beginLayout() {}

  @override
  void endLayout() {}

  @override
  bool shouldLayoutNextItem() => ++_count <= limit;
}

void useDeterministicBudget() {
  setUp(() {
    SuperSliverList.layoutBudget = CountingBudget();
  });
}

/// Height of item [i] helper.
typedef HeightOf = double Function(int index);

Widget tile(int index, double height, {Key? key}) {
  return SizedBox(
    key: key ?? ValueKey<int>(index),
    height: height,
    child: Text("Tile $index"),
  );
}

/// A plain vertical [CustomScrollView] with a single [SuperSliverList].
Widget buildSingleList({
  required int itemCount,
  required HeightOf height,
  required ListController listController,
  required ScrollController scrollController,
  double viewportHeight = 500,
  bool separated = false,
  double separatorHeight = 10,
  bool precise = true,
  bool reverse = false,
  bool scrollAnchoring = true,
  ItemPosition? initialItem,
  bool stickToEnd = false,
  Widget Function(int index)? itemBuilder,
}) {
  Widget item(int i) => itemBuilder?.call(i) ?? tile(i, height(i));
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        height: viewportHeight,
        child: CustomScrollView(
          controller: scrollController,
          reverse: reverse,
          physics: const ClampingScrollPhysics(),
          slivers: [
            if (separated)
              SuperSliverList.separated(
                listController: listController,
                initialItem: initialItem,
                stickToEnd: stickToEnd,
                extentPrecalculationPolicy: precise ? PreciseExtents() : null,
                itemCount: itemCount,
                itemBuilder: (_, i) => item(i),
                separatorBuilder: (_, i) =>
                    SizedBox(height: separatorHeight, child: Text("Sep $i")),
              )
            else
              SuperSliverList.builder(
                listController: listController,
                scrollAnchoring: scrollAnchoring,
                initialItem: initialItem,
                stickToEnd: stickToEnd,
                extentPrecalculationPolicy: precise ? PreciseExtents() : null,
                itemCount: itemCount,
                itemBuilder: (_, i) => item(i),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Convenience: pumps a list and returns once it is laid out.
Future<void> pumpList(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}
