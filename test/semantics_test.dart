import "package:flutter/material.dart";
import "package:flutter/semantics.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

// The lists report the same scroll semantics as Flutter's ListView.
void main() {
  Future<SemanticsData> scrollData(WidgetTester tester, Widget list) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: list)));
    SemanticsData? result;
    void walk(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (data.scrollChildCount != null) {
        result = data;
      }
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
    expect(result, isNotNull);
    return result!;
  }

  testWidgets("SuperListView.builder reports child count and indexes", (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final data = await scrollData(
      tester,
      SuperListView.builder(
        itemCount: 100,
        itemBuilder: (_, i) => SizedBox(height: 100, child: Text("Item $i")),
      ),
    );
    expect(data.scrollChildCount, 100);
    expect(data.scrollIndex, 0);
    expect(tester.getSemantics(find.text("Item 3")).indexInParent, 3);
    handle.dispose();
  });

  testWidgets("SuperListView.separated counts items, not separators", (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final data = await scrollData(
      tester,
      SuperListView.separated(
        itemCount: 50,
        itemBuilder: (_, i) => SizedBox(height: 100, child: Text("Item $i")),
        separatorBuilder: (_, _) => const Divider(height: 1),
      ),
    );
    expect(data.scrollChildCount, 50);
    handle.dispose();
  });
}
