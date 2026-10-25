<p align="center"><img src="assets/icon.png" width="128" alt="leap_sliver_list icon"></p>

# leap_sliver_list

SliverList and ListView - supercharged. A maintained fork of [`super_sliver_list`](https://github.com/superlistapp/super_sliver_list).

> **Migrating from `super_sliver_list`?** Replace the dependency with `leap_sliver_list` and change the import to `package:leap_sliver_list/leap_sliver_list.dart`. The public API (`SuperSliverList`, `SuperListView`, `ListController`, ...) is unchanged.

`SuperSliverList` and `SuperListView` are drop in replacement widgets for `SliverList` and `ListView` with greatly improved performance and additional features:

#### Fast scrolling with large amount of items with variable extents

`SliverList` performance degrades heavily when quickly scrolling through a large amount of items with different extents, requiring workarounds such as using `FixedExtentSliverList` or prototype items. `SuperSliverList` uses different layout algorithm and can handle virtually unlimited number of items with variable extents without any slow-downs.

#### Ability to jump or animate to specific item

`SliverList` does not provide any way to jump or animate a particular index. There is a [scrollable_positioned_list](https://pub.dev/packages/scrollable_positioned_list) package that provides this functionality, but it comes at a cost, as it requires custom scroll view, does not seem to work properly with Scrollbars, can't be used with with other slivers (such as sticky headers) and ultimately is backed by a `SliverList` so it has the same performance issues as mentioned above.

`SuperSliverList` provides a way to reliably jump and animate to a specific item, even if the item is outside of the viewport and has not been built or laid out yet.

#### Smooth and predictable scrollbar behavior

`SliverList` is quite prone to scrollbar erraticaly jumping around when scrolling through a list of items with different extents. With `SuperSliverList` the scrollbar should behave more predictably. See the [Advanced](#advanced) section for more details.

## Basic Usage

`SuperListView` is a drop-in replacement for `ListView`, and as such you can use it same way you'd use `ListView`:

```dart
SuperListView.builder(
  itemCount: 1000,
  itemBuilder: (context, index) {
    return ListTile(title: Text('Item $index'));
  },
)
```

`SuperSliverList` is a drop-in replacement for `SliverList` and should work with any `CustomScrollView` configuration:
 ```dart
 CustomScrollView(
   slivers: <Widget>[
     SliverPadding(
       padding: const EdgeInsets.all(20.0),
       sliver: SuperSliverList(
         delegate: SliverChildListDelegate(
           <Widget>[
             const Text("I'm dedicating every day to you"),
             const Text('Domestic life was never quite my style'),
             const Text('When you smile, you knock me out, I fall apart'),
             const Text('And I thought I was so smart'),
           ],
         ),
       ),
     ),
   ],
 )
 ```

## Jumping and animating to specific item

`ListController` can be provided to `SuperSliverList`/`SuperListView` and used to jump or animate to specific item:

```dart
class _MyState extends State<MyWidget> {
  final _listController = ListController();
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return SuperListView.builder(
      listController: _listController,
      controller: _scrollController,
      itemCount: 1000,
      itemBuilder: (context, index) {
        return ListTile(title: Text('Item $index'));
      },
    );
  }

  void jumpToItem(int index) {
    _listController.jumpToItem(
      index: index,
      scrollController: _scrollController,
      alignment: 0.5,
    );
  }

  void animateToItem(int index) {
    _listController.animateToItem(
      index: () => index,
      scrollController: _scrollController,
      alignment: 0.5,
      // You can provide duration and curve depending on the estimated
      // distance between currentPosition and the target item position.
      duration: (estimatedDistance) => Duration(milliseconds: 250),
      curve: (estimatedDistance) => Curves.easeInOut,
    );
  }
}
```

### Awaiting and canceling animations

`animateToItem` returns an `ItemAnimation`, a `Future<void>` that completes when the animation is over. It never completes with an error: check `isCanceled` to know whether the item was reached.

```dart
final animation = _listController.animateToItem(
  index: () => 500,
  scrollController: _scrollController,
  alignment: 0.5,
  duration: (_) => const Duration(milliseconds: 400),
  curve: (_) => Curves.easeInOut,
);
await animation;
if (animation.isCanceled) {
  // The user scrolled, another animation started, ...
}
animation.cancel(); // stops at the current position
```

### Separated lists

With `SuperSliverList.separated` / `SuperListView.separated`, `ListController` indexes your items, not the separators, so `jumpToItem(index: 10, ...)` shows item 10. Pass `listControllerIndexesItems: false` to get the raw child indexes instead.

### Offsets, visible items and `center`/`anchor`

```dart
_listController.offsetForIndex(42);                 // scroll offset of item 42
_listController.getOffsetToReveal(42, 0.5);         // offset that aligns it to the middle
_listController.firstVisibleIndex;                  // int?
_listController.lastVisibleIndex;                   // int?
```

`jumpToItem`, `animateToItem` and `getOffsetToReveal` honor a custom `center` and `anchor` of the viewport and accept an `obstruction` (`ChildObstructionExtent`) for space covered by something the list does not know about, such as a `SliverStickyHeader` (from `flutter_sticky_header`) wrapping the list:

```dart
_listController.jumpToItem(
  index: 10,
  scrollController: _scrollController,
  alignment: 0.0,
  obstruction: const ChildObstructionExtent(leading: 56, trailing: 0),
);
```

### Inserting items above the viewport

Tell the controller about the insertion and the visible content stays where it is (useful for chats and feeds that prepend older messages):

```dart
setState(() => messages.insertAll(0, olderMessages));
_listController.addItem(0, count: olderMessages.length, preserveScrollPosition: true);
```

The scroll position is compensated exactly for up to 256 inserted items that are not built yet; for larger insertions the estimated extents are used.

### Initial position

`initialItem` scrolls to an item before the first frame is painted, so there is no flash of the top of the list ([upstream #58](https://github.com/superlistapp/super_sliver_list/issues/58)). It uses the same alignment as `jumpToItem` and is applied once, when the list first has items:

```dart
SuperListView.builder(
  initialItem: const ItemPosition(index: 120, alignment: 0.5),
  itemCount: 1000,
  itemBuilder: /*...*/,
)
```

It is ignored when the scroll position is not 0 at that moment (for example with `ScrollController.initialScrollOffset`) and for reverse growth (`center` before the list).

### Chat lists

* **Newest at the bottom:** `stickToEnd: true` keeps the end in view when items are appended (or the last item grows) *while the end was visible*. If the user scrolled away the position is left alone, and the list starts at its end. When combined with `initialItem`, the initial item wins.
* **Newest at the top (`reverse: true`):** nothing special is needed to stay at the newest message; use `addItem(0, preserveScrollPosition: true)` (see below) to keep the position of a user that scrolled back in time.

### Scroll anchoring

When the extent of an item above the first visible item changes (an image loaded, a text expanded), the visible content stays where it is instead of jumping. This is on by default; pass `scrollAnchoring: false` to restore the 0.5 behavior.

### Pixel alignment and snapping

`jumpToItem`, `animateToItem` and `getOffsetToReveal` take an `alignmentOffset` in logical pixels (towards the trailing edge) on top of `alignment`, for example "item 10 with its top 8 px below the viewport top":

```dart
_listController.jumpToItem(
  index: 10,
  scrollController: _scrollController,
  alignment: 0.0,
  alignmentOffset: 8.0,
);
```

`ItemSnapScrollPhysics` makes a list settle with an item aligned, like a pager that is not page-sized:

```dart
SuperListView.builder(
  listController: _listController,
  physics: ItemSnapScrollPhysics(listController: _listController),
  /*...*/
)
```

`ListController.snapTarget(scrollOffset)` returns the item and offset it would settle on. The physics works with a single list; across several lists in one scroll view it snaps to the items of the given controller only.

### Sticky headers

`SuperStickyHeader` pins a header to the leading edge while its list scrolls underneath, and the next header pushes it out. It is built from Flutter's `SliverMainAxisGroup` and `PinnedHeaderSliver`, with no extra package:

```dart
CustomScrollView(slivers: [
  for (final section in sections)
    SuperStickyHeader(
      header: SectionHeader(section),
      sliver: SuperSliverList.builder(/*...*/),
    ),
])
```

`jumpToItem`, `animateToItem` and `getOffsetToReveal` align the item within the part of the viewport that the header does not cover, for any `alignment`, so do not pass an `obstruction` for it. Only headers at the leading edge are supported. Headers from other packages (such as `flutter_sticky_header`) still work with the `obstruction` parameter as described above.

#### Which header is pinned

Give the headers a `StickyHeaderController` and each its `index` to learn which section is the pinned one ([upstream #56](https://github.com/superlistapp/super_sliver_list/issues/56)). It is a `ValueListenable<int?>`:

```dart
final sticky = StickyHeaderController();

SuperStickyHeader(controller: sticky, index: section.id, /*...*/)

ValueListenableBuilder<int?>(
  valueListenable: sticky,
  builder: (context, active, _) => Text("Section $active"),
)
```

The value is the `index` of the last header that reached the leading edge (the lowest attached index before that, `null` without headers). Listeners run after the frame in which it changed, never during layout, and only on change. Only sections that are built are known, so with a section that was scrolled far away the value follows the sections near the viewport. The header is exposed to accessibility services as a header (`Semantics(header: true)`).

#### Sticky footers

`SuperStickyFooter` is the trailing edge counterpart: the footer stays at the bottom of the viewport while its list is scrolling, and rests right after the last item when the end of the list is in view. It works with any axis direction and with `SuperStickyHeader` in the same `CustomScrollView`:

```dart
SuperStickyFooter(
  footer: SectionFooter(section),
  sliver: SuperSliverList.builder(/*...*/),
)
```

`jumpToItem`, `animateToItem` and `getOffsetToReveal` keep the item clear of the footer too. The footer is painted and hit tested above the list. The wrapped sliver must grow forward (the default `GrowthDirection.forward`), which is checked by an assert.

## Advanced

Very roughtly speaking `SuperSliverList` works by estimating the extent of items that are outside of viewport and when these items are scrolled into the viewport cache area the scroll position is transparently adjusted to account of the difference between estimated and actual extents. On small lists this difference may result in scrollbar movement not being perfectly aligned with list movement. `SuperSliverList` provides two ways to rectify this:

### Improve extent estimation

You can register custom callback that will be used to estimate extent of estimated items. This can be useful if you have an idea, atleast approximately, how large the extent of each item is.

```dart
SuperSliverList(
    delegate: /*...*/,
    estimateExtent: (index) => 100.0, // Provide your own extent estimation
)
```

### Adaptive estimation

With the default estimate (100 px) a list of 200 px items reports a scroll extent half the real size until everything was measured. `adaptiveEstimation: true` uses the average extent of the items measured so far for the items that were not measured:

```dart
SuperListView.builder(adaptiveEstimation: true, /*...*/)
```

The extent (and with it the scrollbar thumb size and jumps to far away items) converges while scrolling; the visible items do not move when the estimate is updated. Updates happen when the number of measured items doubles, so the cost stays linear. It is off by default, and ignored when `extentEstimation` is given.

### Estimation per kind of item

When rows come in very different sizes (text, image cards, ads) one average per list is a poor estimate. `itemTypeOf` returns the kind of each item, and every kind gets the average of the measured items of that kind (opt-in, it implies `adaptiveEstimation`):

```dart
SuperListView.builder(
  itemTypeOf: (index) => feed[index].runtimeType,
  /*...*/
)
```

A kind that was not measured yet falls back to the global average. The averages are recomputed when the number of measured items doubles, which calls `itemTypeOf` once for each measured item at that point (keep it cheap). It is ignored when `extentEstimation` is given. With separated lists the index is the index of the item. See the numbers in the benchmark below, the estimator is exact on lists whose kinds have a fixed height and it helps less when the extent varies a lot inside a kind.

### Grid

`SuperSliverGrid` lays out items in a fixed number of columns (or columns of a maximum width) inside a sliver. The rows have the height of their tallest item, so the heights can vary from row to row, and jump and animate work with item indexes through a `GridController`:

```dart
final grid = GridController();

SuperSliverGrid.builder(
  controller: grid,
  crossAxisCount: 3, // or SuperSliverGrid.extent(maxCrossAxisExtent: 200, ...)
  itemCount: 10000,
  mainAxisSpacing: 8,
  crossAxisSpacing: 8,
  itemBuilder: (context, index) => Card(/*...*/),
)

grid.jumpToItem(index: 5000, scrollController: scrollController, alignment: 0);
grid.visibleRange; // (first item, last item) of the visible rows
```

It is a minimal version, built on a `SuperSliverList` of rows (also available as `grid.rows`). Limits: vertical scrolling only, items are top aligned and take the width of their column (they are not stretched to the height of the row), there is no masonry layout (items are not moved to the shortest column), and the columns are not animated when they change. `adaptiveEstimation`, `itemTypeOf` (it receives the index of a row, not of an item) and `scrollAnchoring` are passed to the rows.

### Precalculate extents for items

`SuperSliverList` can, if needed, asynchronously precalculate extents for items. To enfore this, subclass `ExtentPrecalculationPolicy` and provide it to `SuperSliverList`:

In this example the extents are eagerly precalculated for lists with less than 100 items:

```dart
class MyPrecalculationPolicy extends ExtentPrecalculationPolicy {
  @override
  bool shouldPrecaculateExtents(ExtentPrecalculationContext context)  {
    return context.numberOfItems < 100;
  }
}

return SuperSliverList(
    delegate: /*...*/,
    extentPrecalculationPolicy: myPolicy,
)
```

The threshold is arbitrary, but in general there are diminishing returns for precalculating extents for large lists, as the extent estimation error for each item has much smaller impact on the scrollbar position if there are many items.

## Example

See the [example](example) folder for a complete sample app using `SuperSliverList`.

## Benchmark

`benchmark/layout_benchmark.dart` compares `SliverList` and `SuperSliverList` (10,000 items with variable heights) and times `jumpToItem`:

```
flutter test benchmark/layout_benchmark.dart
```

It runs in the headless `flutter_tester` (debug/JIT, software rendering, CPU only), so use it to compare implementations and versions on the same machine, not as device numbers. Tune it with `--dart-define=ITEMS=100000`, `FRAMES` and `RUNS`.

Environment of the figures below: Linux virtual machine, Intel Xeon (8 vCPU), Flutter 3.47.8 (Dart VM test runner, no device, no browser), 10,000 items, 300 frames x 5 runs, three consecutive passes on an idle machine (2026-10-26). Per-frame time of `pump`, mean / p95 in ms, one value per pass:

| Scenario | SliverList | SuperSliverList |
|----------|-----------|-----------------|
| scroll 120 px/frame | 1.81 / 3.55, 1.67 / 3.23, 1.72 / 3.32 | 1.50 / 2.16, 1.44 / 2.17, 1.32 / 1.96 |
| scroll 5000 px/frame | 4.50 / 10.01, 4.28 / 9.52, 4.24 / 9.09 | 1.26 / 2.66, 1.31 / 2.38, 1.14 / 2.09 |
| `jumpToItem` to a random item and settle | not available | 5.08 / 7.87, 5.44 / 8.31, 5.00 / 6.72 |

To check for regressions the same three passes were run on the previous release commit (`d551644`, before sticky footer, grid and per-type estimation) on the same machine in alternation. `SuperSliverList` scroll 120 px/frame: mean 1.28, 1.31, 1.34 ms before and 1.50, 1.44, 1.32 ms now; 5000 px/frame: 1.15, 1.39, 1.14 before and 1.26, 1.31, 1.14 now; `jumpToItem`: 4.83, 5.92, 4.82 before and 5.08, 5.44, 5.00 now. The `SliverList` control moved by a similar amount between passes (1.64 to 1.81 ms), so the differences are within the noise of this machine; the code path of a plain list is unchanged.

`benchmark/estimation_benchmark.dart` compares the extent estimators on 10,000 items, after scrolling 40 screens (600 px) from the top. "feed" is a mix of text rows, cards and ads; "shifted" starts with small rows and continues with mostly cards, so the first measured items do not describe the rest. The error and movement figures are deterministic (identical in the three passes); frame time is the median frame, three passes:

| List | Estimator | Error of the total extent | Scrollbar back-and-forth | Median frame (ms) |
|------|-----------|--------------------------|--------------------------|-------------------|
| feed | default (100 px) | 20.2 % | 0 px | 5.85, 6.13, 6.42 |
| feed | `adaptiveEstimation` | 0.4 % | 387,281 px | 4.58, 5.09, 5.02 |
| feed | `itemTypeOf` | 0.0 % | 51,429 px | 3.95, 4.82, 4.36 |
| shifted | default (100 px) | 53.9 % | 3,920 px | 4.43, 4.56, 4.42 |
| shifted | `adaptiveEstimation` | 59.1 % | 223,256 px | 3.96, 4.03, 4.04 |
| shifted | `itemTypeOf` | 0.0 % | 0 px | 3.34, 3.95, 3.57 |

"Scrollbar back-and-forth" is how many pixels the total extent moved up and down on the way (movement beyond the net change), so a lower value means a steadier scrollbar thumb. The default estimator never moves back and down but it is simply wrong (20 % and 54 % off at the end). `adaptiveEstimation` is closer on the feed but moves the total a lot while it learns, and on the shifted list it is worse than the default because it learns from the small rows. Per kind estimation is the best of the three on these two lists, but it needs the kind of each item and the benchmark heights are fixed per kind; with heights that vary inside a kind the error will not be zero. The frame time differences between estimators (about 1 ms) are small compared to the run to run variation, so they are not a claim about speed.

## Roadmap

Not done yet:

* A sectioned list helper, and sticky headers or footers for slivers that grow in reverse.
* Grid: masonry layout (shortest column first), items stretched to the row height, horizontal scrolling, a SliverGrid style delegate.
* An estimator with a moving window for lists whose kinds change height along the list, and a better scrollbar for huge lists.
* Accessibility: headers are exposed as headers and the scroll children match `ListView`; the footer and the grid have no extra semantics beyond their children. Not tested with a screen reader.
* Integration tests on devices, and benchmarks on web/wasm. Only the Dart VM test runner and the web build are verified today; iOS and Android are not.

## Attribution

`leap_sliver_list` is a fork of [`super_sliver_list`](https://github.com/superlistapp/super_sliver_list) v0.4.1 by Matej Knopp, Superlist and the contributors, released under the MIT license. The original code is imported at upstream commit `bfa3d5d` (without its git history) and is maintained here. This project is not affiliated with or endorsed by Superlist. See [NOTICE](NOTICE) and [LICENSE](LICENSE).
