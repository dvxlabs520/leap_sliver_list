import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "support.dart";

// Upstream issues #76, #82, #86, #92, #93, #97: animateToItem was not
// awaitable, could not be canceled and leaked its AnimationController when the
// list was removed while animating.
void main() {
  useDeterministicBudget();

  Future<(ListController, ScrollController)> pump(WidgetTester tester) async {
    final list = ListController();
    final scroll = ScrollController();
    addTearDown(list.dispose);
    addTearDown(scroll.dispose);
    await pumpList(
      tester,
      buildSingleList(
        itemCount: 100,
        height: (_) => 100,
        listController: list,
        scrollController: scroll,
      ),
    );
    return (list, scroll);
  }

  ItemAnimation animate(
    ListController list,
    ScrollController scroll,
    int? Function() index,
  ) {
    return list.animateToItem(
      index: index,
      scrollController: scroll,
      alignment: 0,
      duration: (_) => const Duration(milliseconds: 500),
      curve: (_) => Curves.linear,
    );
  }

  testWidgets("future completes when the animation is done", (tester) async {
    final (list, scroll) = await pump(tester);
    var done = false;
    final animation = animate(list, scroll, () => 20)..then((_) => done = true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(done, isFalse);
    expect(animation.isCompleted, isFalse);
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(animation.isCompleted, isTrue);
    expect(animation.isCanceled, isFalse);
    expect(scroll.offset, 2000);
  });

  testWidgets("cancel stops the animation and completes the future", (
    tester,
  ) async {
    final (list, scroll) = await pump(tester);
    var done = false;
    final animation = animate(list, scroll, () => 20)..then((_) => done = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final offset = scroll.offset;
    expect(offset, greaterThan(0));
    animation.cancel();
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(animation.isCanceled, isTrue);
    expect(scroll.offset, offset);
  });

  testWidgets("removing the list mid-animation does not leak the ticker", (
    tester,
  ) async {
    final (list, scroll) = await pump(tester);
    var done = false;
    animate(list, scroll, () => 20).then((_) => done = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(done, isTrue);
  });

  testWidgets("dragging the list cancels the animation", (tester) async {
    final (list, scroll) = await pump(tester);
    final animation = animate(list, scroll, () => 20);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -20));
    await tester.pumpAndSettle();
    expect(animation.isCanceled, isTrue);
    expect(scroll.offset, lessThan(2000));
  });

  testWidgets("starting a new animation cancels the previous one", (
    tester,
  ) async {
    final (list, scroll) = await pump(tester);
    final first = animate(list, scroll, () => 40);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final second = animate(list, scroll, () => 10);
    await tester.pumpAndSettle();
    expect(first.isCanceled, isTrue);
    expect(second.isCompleted, isTrue);
    expect(second.isCanceled, isFalse);
    expect(scroll.offset, 1000);
  });

  testWidgets("jumpToItem cancels a running animation", (tester) async {
    final (list, scroll) = await pump(tester);
    final animation = animate(list, scroll, () => 40);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    list.jumpToItem(index: 5, scrollController: scroll, alignment: 0);
    await tester.pumpAndSettle();
    expect(animation.isCanceled, isTrue);
    expect(scroll.offset, 500);
  });

  testWidgets("null index completes the future as canceled", (tester) async {
    final (list, scroll) = await pump(tester);
    final animation = animate(list, scroll, () => null);
    await tester.pumpAndSettle();
    await animation;
    expect(animation.isCanceled, isTrue);
    expect(scroll.offset, 0);
  });

  testWidgets("index getter returning null mid-animation stops it", (
    tester,
  ) async {
    final (list, scroll) = await pump(tester);
    int? target = 20;
    final animation = animate(list, scroll, () => target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    target = null;
    await tester.pumpAndSettle();
    expect(animation.isCanceled, isTrue);
    expect(scroll.offset, lessThan(2000));
  });
}
