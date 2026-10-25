import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

class _Host extends StatefulWidget {
  const _Host({
    required this.heights,
    required this.controller,
    required this.list,
    this.scrollAnchoring = true,
  });

  final Map<int, double> heights;
  final ScrollController controller;
  final ListController list;
  final bool scrollAnchoring;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  void resize(int index, double height) {
    setState(() => widget.heights[index] = height);
  }

  @override
  Widget build(BuildContext context) {
    return buildSingleList(
      itemCount: 100,
      height: (i) => widget.heights[i] ?? 50,
      listController: widget.list,
      scrollController: widget.controller,
      precise: true,
      scrollAnchoring: widget.scrollAnchoring,
    );
  }
}

void main() {
  useDeterministicBudget();

  Future<(_HostState, ScrollController, ListController)> pumpHost(
    WidgetTester tester, {
    bool scrollAnchoring = true,
    Map<int, double>? heights,
  }) async {
    final controller = ScrollController();
    final list = ListController();
    addTearDown(controller.dispose);
    addTearDown(list.dispose);
    await pumpList(
      tester,
      _Host(
        heights: heights ?? {},
        controller: controller,
        list: list,
        scrollAnchoring: scrollAnchoring,
      ),
    );
    final state = tester.state<_HostState>(find.byType(_Host));
    return (state, controller, list);
  }

  double topOf(WidgetTester tester, int index) =>
      tester.getTopLeft(find.byKey(ValueKey<int>(index))).dy;

  testWidgets("growing an item above the viewport keeps content in place", (
    tester,
  ) async {
    final (state, controller, _) = await pumpHost(tester);
    controller.jumpTo(2000);
    await tester.pumpAndSettle();
    final before = topOf(tester, 40);

    // Item 36 is in the cache area above the viewport.
    state.resize(36, 200);
    await tester.pumpAndSettle();

    expect(topOf(tester, 40), before);
    expect(controller.offset, 2150);
  });

  testWidgets("shrinking an item above the viewport keeps content in place", (
    tester,
  ) async {
    final (state, controller, _) = await pumpHost(tester, heights: {36: 200});
    controller.jumpTo(2150);
    await tester.pumpAndSettle();
    final before = topOf(tester, 40);

    state.resize(36, 50);
    await tester.pumpAndSettle();

    expect(topOf(tester, 40), before);
    expect(controller.offset, 2000);
  });

  testWidgets("resizing a visible item moves only the items below it", (
    tester,
  ) async {
    final (state, controller, _) = await pumpHost(tester);
    controller.jumpTo(2000);
    await tester.pumpAndSettle();
    final top41 = topOf(tester, 41);
    final top42 = topOf(tester, 42);

    state.resize(41, 100);
    await tester.pumpAndSettle();

    expect(controller.offset, 2000);
    expect(topOf(tester, 41), top41);
    expect(topOf(tester, 42), top42 + 50);
  });

  testWidgets("scrollAnchoring: false keeps the previous behavior", (
    tester,
  ) async {
    final (state, controller, _) = await pumpHost(
      tester,
      scrollAnchoring: false,
    );
    controller.jumpTo(2000);
    await tester.pumpAndSettle();
    final before = topOf(tester, 40);

    state.resize(36, 200);
    await tester.pumpAndSettle();

    expect(topOf(tester, 40), before + 150);
    expect(controller.offset, 2000);
  });
}
