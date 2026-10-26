## 0.6.0

Released 2026-10-26. New features. All changes are backwards compatible (additions only).

### New API

* `initialItem` (`ItemPosition`) on `SuperSliverList` and `SuperListView`: start at an item, without a flash of the first items ([upstream #58](https://github.com/superlistapp/super_sliver_list/issues/58)).
* `stickToEnd`: keep the end of the list in view while items arrive, for chat lists.
* `scrollAnchoring` (default `true`): when the extent of an item above the first visible one changes, the visible content stays in place.
* `alignmentOffset` on `jumpToItem`, `animateToItem` and `getOffsetToReveal`: pixel-precise alignment on top of `alignment`.
* `ItemSnapScrollPhysics` and `ListController.snapTarget`: settle with an item aligned.
* `adaptiveEstimation` (opt-in): the estimate for items that were not measured follows the measured average, so the scroll extent and scrollbar converge faster.
* `StickyHeaderController` (a `ValueListenable<int?>`) with `controller` and `index` on `SuperStickyHeader`: tells which header is pinned ([upstream #56](https://github.com/superlistapp/super_sliver_list/issues/56)). Notifies after the frame, only on change. The header is exposed as a semantics header.
* `SuperStickyFooter`: a footer that sticks to the trailing edge of the viewport while its sliver scrolls; `jumpToItem`, `animateToItem` and `getOffsetToReveal` keep the item clear of it.
* `itemTypeOf` (opt-in, implies `adaptiveEstimation`) on `SuperSliverList` and `SuperListView`: the estimate of an unmeasured item is the average of the measured items of the same kind.
* `SuperSliverGrid` (`.builder` with `crossAxisCount`, `.extent` with `maxCrossAxisExtent`) and `GridController` (`jumpToItem`, `animateToItem`, `visibleRange` with item indexes). Minimal version: vertical, rows as tall as their tallest item, no masonry. See the README for the limits.
* `SuperStickyHeader`: native sticky header built from `SliverMainAxisGroup` and `PinnedHeaderSliver`; the `ListController` methods align items below it. For alignments other than 0 the offset Flutter's group computes leaves the item partly outside the viewport, this is corrected.

### Other

* Example app rewritten as a Material 3 demo (big list, chat, sections with sticky headers, footers and the pinned section, grid, anchoring, `SliverList` comparison with frame time meter, light/dark theme) with widget tests.
* The example deploy workflow now has `contents: write` permission and commits as the repository owner.
* `benchmark/estimation_benchmark.dart` compares the estimators; the README has the figures of three passes and the environment.
* The adaptive estimation test that checked that visible items stay in place did not fail when the correction was removed; it now does (verified by mutation).
* New widget tests for each feature, plus semantics tests that guard parity with `ListView` (scroll child count and item indexes).

## 0.5.0

Bug fixes and new API. All changes are backwards compatible (additions only; `animateToItem` now returns an `ItemAnimation` instead of `void`).

### Fixes

* `jumpToItem` / `animateToItem` / `getOffsetToReveal` land on the right item with `SuperSliverList.separated` and `SuperListView.separated` ([upstream #83](https://github.com/superlistapp/super_sliver_list/issues/83)). The controller now indexes items (not items plus separators) when `listControllerIndexesItems` is true, which is the default for the `.separated` constructors.
* `jumpToItem` / `animateToItem` work with a custom `center` and `anchor` of the viewport ([upstream #59](https://github.com/superlistapp/super_sliver_list/issues/59)), including slivers placed before the center (reverse growth direction).
* Negative or out of range `alignment` values behave consistently ([upstream #84](https://github.com/superlistapp/super_sliver_list/issues/84)); covered by regression tests.
* Lists inside a `SliverStickyHeader` (and other pinned parents) can be jumped/animated to: `getOffsetToReveal` no longer returns an infinite offset, and the new `obstruction` parameter keeps the target item clear of the header ([upstream #85](https://github.com/superlistapp/super_sliver_list/issues/85)).
* `animateToItem` rework: no leaked animation controllers or ticker listeners, cancellation when the user drags, when another animation or jump starts, when the index getter returns `null` or when the list is disposed ([upstream #76](https://github.com/superlistapp/super_sliver_list/pull/76), [#92](https://github.com/superlistapp/super_sliver_list/pull/92), [#93](https://github.com/superlistapp/super_sliver_list/pull/93), [#97](https://github.com/superlistapp/super_sliver_list/pull/97); issues [#82](https://github.com/superlistapp/super_sliver_list/issues/82), [#86](https://github.com/superlistapp/super_sliver_list/issues/86)).

### New API

* `ListController.animateToItem` returns an `ItemAnimation`: a `Future<void>` that completes when the animation ends, with `isCompleted`, `isCanceled` and `cancel()` ([upstream #86](https://github.com/superlistapp/super_sliver_list/issues/86)).
* `ListController.offsetForIndex(index)` ([upstream #95](https://github.com/superlistapp/super_sliver_list/pull/95)) and a public `ListController.getOffsetToReveal(index, alignment, {rect, obstruction})` ([upstream #99](https://github.com/superlistapp/super_sliver_list/pull/99)).
* `ListController.firstVisibleIndex` / `lastVisibleIndex` ([upstream #62](https://github.com/superlistapp/super_sliver_list/issues/62)).
* `ListController.addItem(index, {count, preserveScrollPosition})`: keep the content in place when items are inserted above the viewport (prepending to a chat/feed) ([upstream #71](https://github.com/superlistapp/super_sliver_list/issues/71)).
* `ChildObstructionExtent` parameter (`obstruction`) on `jumpToItem`, `animateToItem` and `getOffsetToReveal`.
* `SuperSliverList.listControllerIndexesItems` (and the same flag on `SuperListView` constructors).

### Other

* Reproducible benchmark in `benchmark/layout_benchmark.dart`.
* Many new widget tests (79 in total).
* Not addressed: initial scroll position ([upstream #58](https://github.com/superlistapp/super_sliver_list/issues/58)); use `ScrollController.initialScrollOffset` or call `jumpToItem` after the first frame.

## 0.5.0-dev

* Fork of [`super_sliver_list` 0.4.1](https://github.com/superlistapp/super_sliver_list) (upstream commit `bfa3d5d`), now maintained as `leap_sliver_list`.
* Package renamed to `leap_sliver_list`; library entry point is now `package:leap_sliver_list/leap_sliver_list.dart`. Public API is otherwise unchanged.
* Migrated deprecated `cacheExtent` usage to `scrollCacheExtent`. `SuperListView` constructors accept both `cacheExtent` (kept for compatibility) and the new `scrollCacheExtent`. Minimum is now Flutter 3.41 / Dart 3.11.
* Cleaned up trivial analyzer lints (e.g. `withOpacity`).

## 0.4.1

* Fix missing propagation of `rect` inside `RenderViewportExt.getOffsetToRevealExt`.
* Add missing constructors in `SuperSliverList` to have `SliverList` parity.

## 0.4.0

* BREAKING: Changed signature of `ExtentEstimationProvider` where the `index` is now nullable.
* Added `layoutKeptAliveChildren` argument to `SuperSliverList`.
* Improved performance with very large lists (millions of items).
* Bugfixes

## 0.3.0

* Fixed layout exception for shrink-wrapped lists.
* BREAKING: ExtentPrecalculationContext.viewportMainAxisExtent is now nullable

## 0.2.2

* Fixed exception when calling markAllDirty on empty list.

## 0.2.1

* Prevent overscroll when jumping and animating to items at the edge with alignment that would otherwise cause overscroll. For example jumping to the first item with `alignment: 1.0` or jumping to the last item with `alignment: 0.0` should no longer cause overscroll.

## 0.2.0

* Added `visibleRange` and `unobstructedVisibleRange` properties to `ListController`.
* Layout fixes.
* Renamed `ExtentController` to `ListController`.

## 0.2.0-dev.2

* Introduced the concept of child obstruction extent. This is a property that
  can be set on Sliver geometry and allows for reliable positioning of items
  in slivers that are wrapped in a sticky header sliver.
* Added sticky headers to example.

## 0.2.0-dev.1

This is a major update and a complete rewrite of `SuperSliverList`.
* Added `SuperListView` as a convenient drop-in replacement for `ListView`.
* Added ability to jump / animate to specific item using `ExtentController`.
* Added ability to asynchronously precompute item extents using `ExtentPrecalculationPolicy`.
* Comprehensive test coverage.

## 0.0.8

* Fixed problem when accessing layout offset from a LayoutBuilder child widget.

## 0.0.7

* Fix inserted children not being build properly.

## 0.0.6

* Bug fixes

## 0.0.5

* Bug fixes

## 0.0.4

* Bug fixes

## 0.0.3

* Various bug fixes and improvements

## 0.0.2

* Various bug fixes

## 0.0.1

* Initial release


