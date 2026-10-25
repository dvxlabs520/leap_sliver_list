import "package:example/app.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const DemoApp());
}

Future<void> _openPage(WidgetTester tester, String title) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text(title),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("big list jumps, animates and cancels", (tester) async {
    await _pumpApp(tester);
    expect(find.text("Item 0"), findsOneWidget);

    await tester.tap(find.text("Jump"));
    await tester.pumpAndSettle();
    expect(find.text("Item 5000"), findsOneWidget);
    expect(find.text("Item 0"), findsNothing);

    await tester.tap(find.text("Animate"));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets("chat adds messages above and below", (tester) async {
    await _pumpApp(tester);
    await _openPage(tester, "Chat");
    expect(find.text("#59"), findsOneWidget);

    await tester.tap(find.text("Add below"));
    await tester.pumpAndSettle();
    // Still at the end: the new message is visible.
    expect(find.text("#60"), findsOneWidget);

    await tester.tap(find.text("Add 10 above"));
    await tester.pumpAndSettle();
    expect(find.text("#60"), findsOneWidget);
    expect(find.text("#-1"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("sections keep the header and align items below it", (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openPage(tester, "Sections");
    expect(find.byKey(const ValueKey("header-0")), findsOneWidget);

    await tester.tap(find.text("Jump"));
    await tester.pumpAndSettle();
    // Section 6, item 15 is centered in the area below the sticky header.
    expect(find.text("Section 6, item 15"), findsOneWidget);
    final header = tester.getRect(find.byKey(const ValueKey("header-6")));
    final item = tester.getRect(find.text("Section 6, item 15"));
    expect(header.top, lessThan(item.top));
    final viewport = tester.getRect(find.byType(Scrollable).last);
    expect(item.center.dy, closeTo(viewport.center.dy + 22, 40));
    expect(tester.takeException(), isNull);
  });

  testWidgets("anchoring keeps visible items in place", (tester) async {
    for (final anchoring in [true, false]) {
      await tester.pumpWidget(const SizedBox());
      await _pumpApp(tester);
      await _openPage(tester, "Anchoring");
      if (!anchoring) {
        await tester.tap(find.text("Scroll anchoring"));
        await tester.pumpAndSettle();
      }
      final before = tester.getTopLeft(find.text("Item 100")).dy;
      await tester.tap(find.text("Expand 2 items above the view"));
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(find.text("Item 100")).dy;
      if (anchoring) {
        expect(after, closeTo(before, 0.5));
      } else {
        expect(after - before, greaterThan(100));
      }
    }
  });

  testWidgets("theme can be switched", (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byTooltip("Dark theme"));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).brightness, Brightness.dark);
    await tester.tap(find.byTooltip("Light theme"));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.light);
  });
}
