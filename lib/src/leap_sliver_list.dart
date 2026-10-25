import "dart:math" as math;

import "package:flutter/rendering.dart";
import "package:flutter/widgets.dart";
import "package:logging/logging.dart";

import "animate_to_item.dart";
import "element.dart";
import "extent_manager.dart";
import "layout_budget.dart";
import "render_object.dart";
import "sliver_extensions.dart";

final _log = Logger("SuperSliverList");

@Deprecated("Use ListController instead.")
typedef ExtentController = ListController;

/// Interface to the sliver list.
///
/// List controller can be used to
/// - jump or animate to a specific item in the list
/// - query the extent of an item
/// - query total number of item as well as number of items with estimated extents
/// - invalidate extent of an item to force recalculation
///
/// List controller can only be attached to a single [SuperSliverList] at a time.
/// All methods except [isAttached] will throw if the controller is not attached.
///
/// List controller is also a [ChangeNotifier] and will notify its listeners
/// if the underlying list or item extents change.
///
/// Example usage:
/// ```dart
///class _MyState extends State<MyWidget> {
///  final _listController = ListController();
///  final _scrollController = ScrollController();
///
///  @override
///  Widget build(BuildContext context) {
///    return SuperListView.builder(
///      listController: _listController,
///      controller: _scrollController,
///      itemCount: 1000,
///      itemBuilder: (context, index) {
///        return ListTile(title: Text('Item $index'));
///      },
///    );
///  }
///
///  void jumpToItem(int index) {
///    _listController.jumpToItem(
///      index: index,
///      scrollController: _scrollController,
///      alignment: 0.5,
///    );
///  }
///}
///```
class ListController extends ChangeNotifier {
  ListController({this.onAttached, this.onDetached});

  /// Callback invoked when the controller is attached to a [SuperSliverList].
  final VoidCallback? onAttached;

  /// Callback invoked when the controller is detached from a [SuperSliverList].
  final VoidCallback? onDetached;

  /// Returns `true` if the controller is attached to a [SuperSliverList].
  bool get isAttached => _delegate != null;

  /// Immediately positions the scroll view such that the item at [index] is
  /// revealed in the viewport.
  ///
  /// The optional [rect] parameter describes which area of that target item
  /// should be revealed in the viewport. If omitted, the entire item
  /// will be revealed (subject to the constraints of the viewport).
  ///
  /// The [alignment] parameter controls where the item is positioned in the
  /// viewport. If the value is 0.0, the item will be positioned at the leading
  /// edge of the viewport. If the value is 0.5, the item will be positioned in
  /// the middle of the viewport. If the value is 1.0, the item will be
  /// positioned at the trailing edge of the viewport.
  ///
  /// The optional [obstruction] describes space at the edges of the viewport
  /// that is covered by something the list does not know about, for example
  /// a `SliverStickyHeader` wrapping this list. The item is aligned within the
  /// remaining area (see [ChildObstructionExtent]).
  void jumpToItem({
    required int index,
    required ScrollController scrollController,
    required double alignment,
    double alignmentOffset = 0.0,
    Rect? rect,
    ChildObstructionExtent? obstruction,
  }) {
    assert(_delegate != null, "ListController is not attached.");
    for (final position in scrollController.positions) {
      _cancelAnimations(position);
    }
    final offset = getOffsetToReveal(
      index,
      alignment,
      alignmentOffset: alignmentOffset,
      rect: rect,
      obstruction: obstruction,
    );
    if (offset.isFinite) {
      final minExtent = scrollController.position.minScrollExtent;
      final maxExtent = scrollController.position.maxScrollExtent;
      final pixels = scrollController.position.pixels;
      // If the scroll view is already at the edge don't do anything.
      // Otherwise this may result in scrollbar handle artifacts.
      if ((offset <= minExtent && pixels == minExtent) ||
          (offset >= maxExtent && pixels == maxExtent)) {
        return;
      }
      scrollController.jumpTo(offset);
    } else {
      _log.warning("getOffsetToReveal returned non-finite value.");
    }
  }

  /// Animates the position of the scroll view such that the item at [index] is
  /// revealed in the viewport.
  ///
  /// The index getter will be called repeatedly on every animation tick, which
  /// allows for accommodating index changes when items are inserted or removed
  /// during the animation. Returning `null` from the index getter will stop
  /// the animation.
  ///
  /// The optional [rect] parameter describes which area of that target item
  /// should be revealed in the viewport. If omitted, the entire item
  /// will be revealed (subject to the constraints of the viewport).
  ///
  /// The [alignment] parameter controls where the item is positioned in the
  /// viewport. If the value is 0.0, the item will be positioned at the leading
  /// edge of the viewport. If the value is 0.5, the item will be positioned in
  /// the middle of the viewport. If the value is 1.0, the item will be
  /// positioned at the trailing edge of the viewport.
  ///
  /// The optional [obstruction] describes space at the edges of the viewport
  /// that is covered by something the list does not know about, for example
  /// a `SliverStickyHeader` wrapping this list. The item is aligned within the
  /// remaining area (see [ChildObstructionExtent]).
  ///
  /// Returns an [ItemAnimation] that can be awaited and canceled. The animation
  /// is canceled automatically when the user scrolls the list, when another
  /// animation or [jumpToItem] starts on the same scroll position and when
  /// the controller is detached from the list.
  ItemAnimation animateToItem({
    required ValueGetter<int?> index,
    required ScrollController scrollController,
    required double alignment,
    required Duration Function(double estimatedDistance) duration,
    required Curve Function(double estimatedDistance) curve,
    double alignmentOffset = 0.0,
    Rect? rect,
    ChildObstructionExtent? obstruction,
  }) {
    assert(_delegate != null, "ListController is not attached.");
    final parts = <AnimateToItem>[];
    for (final position in scrollController.positions.toList()) {
      _cancelAnimations(position);
      late final AnimateToItem part;
      part = AnimateToItem(
        onFinished: () => _animations.remove(part),
        extentManager: _delegate!,
        index: () {
          final itemIndex = index();
          return itemIndex == null ? null : _childIndex(itemIndex);
        },
        alignment: alignment,
        rect: rect,
        obstruction: withAlignmentOffset(
          obstruction,
          alignment,
          alignmentOffset,
        ),
        position: position,
        curve: curve,
        duration: duration,
      );
      _animations.add(part);
      parts.add(part);
    }
    final animation = ItemAnimation.internal(parts);
    for (final part in parts) {
      part.start();
    }
    return animation;
  }

  final _animations = <AnimateToItem>{};

  void _cancelAnimations([ScrollPosition? position]) {
    for (final animation in _animations.toList()) {
      if (position == null || animation.position == position) {
        animation.cancel();
      }
    }
  }

  /// Returns the range of items indices currently visible in the viewport.
  (int, int)? get visibleRange {
    assert(_delegate != null, "ListController is not attached.");
    return _itemRange(_delegate!.visibleRange);
  }

  /// Returns range of items indices currently visible in the viewport
  /// unobstructed by sticky headers or other obstructions.
  (int, int)? get unobstructedVisibleRange {
    assert(_delegate != null, "ListController is not attached.");
    return _itemRange(_delegate!.unobstructedVisibleRange);
  }

  /// Returns the total number of items in the list.
  int get numberOfItems {
    assert(_delegate != null, "ListController is not attached.");
    final children = _delegate!.numberOfItems;
    return _delegate!.separated ? (children + 1) ~/ 2 : children;
  }

  /// Returns the number of items in the list with estimated extent.
  int get numberOfItemsWithEstimatedExtent {
    assert(_delegate != null, "ListController is not attached.");
    return _delegate!.numberOfItemsWithEstimatedExtent;
  }

  /// Returns the scroll offset of the leading edge of the item at [index],
  /// relative to the start of this list (not the whole scroll view).
  ///
  /// The value may be an estimate if items before [index] have not been laid
  /// out yet (see [extentForIndex]).
  double offsetForIndex(int index) {
    assert(_delegate != null, "ListController is not attached.");
    return _delegate!.offsetForIndex(_childIndex(index));
  }

  /// Returns the extent of the item at [index].
  ///
  /// If `isEstimated` is `true`, the returned extent is an estimate and may not
  /// have been obtained by laying out the item and measuring the item.
  ///
  /// If `isEstimated` is `false`, the returned extent is the actual extent of
  /// the item. However if the item is not currently in the cache area the
  /// returned extent may be outdated and will be updated when the item is
  /// scrolled into view, laid out and measured.
  (double, bool isEstimated) extentForIndex(int index) {
    assert(_delegate != null, "ListController is not attached.");
    return _delegate!.extentForIndex(_childIndex(index));
  }

  /// Returns the sum of all the extents of the items in the list.
  double get totalExtent {
    assert(_delegate != null, "ListController is not attached.");
    return _delegate!.totalExtent;
  }

  /// Returns whether the underlying list is currently locked.
  ///
  /// Methods that modify the underlying extent list, such as [invalidateExtent],
  /// [invalidateAllExtents], [addItem], and [removeItem], will throw if called
  /// when list is locked.
  ///
  /// The list is locked during layout and unlock after the layout is complete.
  bool get isLocked {
    assert(_delegate != null, "ListController is not attached.");
    return _delegate!.isLocked;
  }

  /// Invalidates the extent of the item at [index]. Invalidating extent will
  /// treat the extent as an estimation and will recalculate the extent if the
  /// [ExtentPrecalculationPolicy] allows for eagerly precalculating extents.
  void invalidateExtent(int index) {
    assert(_delegate != null, "ListController is not attached.");
    final child = _childIndex(index);
    _delegate!.invalidateExtent(child);
    if (_delegate!.separated && child + 1 < _delegate!.numberOfItems) {
      _delegate!.invalidateExtent(child + 1);
    }
  }

  /// Invalidates the extent of all items in the list.
  /// All extents will be treated as estimations and will be recalculated if the
  /// [ExtentPrecalculationPolicy] allows for eagerly precalculating extents.
  void invalidateAllExtents() {
    assert(_delegate != null, "ListController is not attached.");
    _delegate!.invalidateAllExtents();
  }

  /// Signals that [count] new items have been added to the list at [index].
  /// This shift all extents after the [index] by [count] and will create new
  /// estimated extents for the new items.
  ///
  /// Being able to notify the list of an item being added is useful when
  /// eagerly precalculating extents.
  ///
  /// With [preserveScrollPosition] set to `true` and the items inserted above
  /// the leading edge of the viewport, the scroll position is adjusted by the
  /// extent of the new items, so the items that were visible stay where they
  /// are. This is what chat-like lists need when older items are prepended.
  /// Call this in the same frame in which the item count changes.
  void addItem(
    int index, {
    int count = 1,
    bool preserveScrollPosition = false,
  }) {
    assert(_delegate != null, "ListController is not attached.");
    assert(count >= 0);
    if (count == 0) {
      return;
    }
    final manager = _delegate!;
    if (!manager.separated) {
      manager.addItem(
        index,
        count: count,
        preserveScrollPosition: preserveScrollPosition,
      );
      return;
    }
    final children = manager.numberOfItems;
    // Each new item comes with a separator. When appending, the separator
    // goes before the item.
    final int childIndex;
    final int childCount;
    if (children == 0) {
      childIndex = 0;
      childCount = count * 2 - 1;
    } else if (index * 2 >= children + 1) {
      childIndex = children;
      childCount = count * 2;
    } else {
      childIndex = index * 2;
      childCount = count * 2;
    }
    manager.addItem(
      childIndex,
      count: childCount,
      preserveScrollPosition: preserveScrollPosition,
    );
  }

  /// Signals that an item has been removed from the list at [index].
  /// This shift all extents after the [index] by one and will remove the
  /// extent of the removed item.
  ///
  /// Being able to notify the list of an item being removed is useful when
  /// eagerly precalculating extents.
  void removeItem(int index) {
    assert(_delegate != null, "ListController is not attached.");
    final manager = _delegate!;
    if (!manager.separated) {
      manager.removeItem(index);
      return;
    }
    final children = manager.numberOfItems;
    final child = index * 2;
    if (children <= 1) {
      manager.removeItem(child);
    } else if (child + 1 < children) {
      // Remove the item together with the separator that follows it.
      manager.removeItem(child);
      manager.removeItem(child);
    } else {
      // Last item: remove the separator that precedes it.
      manager.removeItem(child);
      manager.removeItem(child - 1);
    }
  }

  // Translates an item index to the index of the corresponding child.
  int _childIndex(int itemIndex) =>
      _delegate!.separated ? itemIndex * 2 : itemIndex;

  // Translates a range of child indices to a range of item indices.
  (int, int)? _itemRange((int, int)? children) {
    if (children == null || !_delegate!.separated) {
      return children;
    }
    final start = (children.$1 + 1) ~/ 2;
    final end = children.$2 ~/ 2;
    return start > end ? null : (start, end);
  }

  /// Index of the first item visible in the viewport, or `null` if no item
  /// is visible. Items that are partially visible count as visible.
  ///
  /// This is the same as the start of [visibleRange].
  int? get firstVisibleIndex => visibleRange?.$1;

  /// Index of the last item visible in the viewport, or `null` if no item
  /// is visible. Items that are partially visible count as visible.
  ///
  /// This is the same as the end of [visibleRange].
  int? get lastVisibleIndex => visibleRange?.$2;

  @override
  void dispose() {
    if (_delegate != null) {
      unsetDelegate(_delegate!);
    }
    super.dispose();
  }

  ExtentManager? _delegate;

  void setDelegate(ExtentManager delegate) {
    if (_delegate == delegate) {
      return;
    }
    if (_delegate != null) {
      _cancelAnimations();
      onDetached?.call();
    }
    _delegate?.removeListener(notifyListeners);
    _delegate = delegate;
    _delegate?.addListener(notifyListeners);
    if (_delegate != null) {
      onAttached?.call();
    }
  }

  void unsetDelegate(ExtentManager delegate) {
    if (_delegate == delegate) {
      _cancelAnimations();
      _delegate?.removeListener(notifyListeners);
      _delegate = null;
      onDetached?.call();
    }
  }

  /// Returns the scroll offset at which the item at [index] would sit at
  /// [alignment] within the viewport, where 0.0 is the leading edge and 1.0 the
  /// trailing edge.
  ///
  /// This is the offset that [jumpToItem] scrolls to. Together with the current
  /// scroll offset it gives an item's position in the viewport, which is
  /// useful for questions such as "which is the topmost item not hidden behind
  /// a header?".
  ///
  /// The optional [obstruction] works as in [jumpToItem].
  ///
  /// The returned value may be an estimate if the item (or items before it)
  /// have not been laid out yet. It is not clamped to the scroll extent.
  double getOffsetToReveal(
    int index,
    double alignment, {
    double alignmentOffset = 0.0,
    Rect? rect,
    ChildObstructionExtent? obstruction,
  }) {
    assert(_delegate != null, "ListController is not attached.");
    return _delegate!.getOffsetToReveal(
      _childIndex(index),
      alignment,
      rect: rect,
      obstruction: withAlignmentOffset(obstruction, alignment, alignmentOffset),
      estimationOnly: false,
    );
  }

  /// Finds the item that is closest to being aligned (as in [jumpToItem]) when
  /// the scroll position is [scrollOffset], and the scroll offset that aligns
  /// it exactly. Returns `null` for an empty list or if no item is laid out yet.
  ///
  /// This is what [ItemSnapScrollPhysics] uses. The search relies on the
  /// current (possibly estimated) extents, so it is cheap and does not build
  /// any items. It assumes an [alignment] between 0.0 and 1.0.
  ItemSnapTarget? snapTarget(
    double scrollOffset, {
    double alignment = 0.0,
    double alignmentOffset = 0.0,
    ChildObstructionExtent? obstruction,
  }) {
    assert(_delegate != null, "ListController is not attached.");
    final range = visibleRange;
    final count = numberOfItems;
    if (range == null || count == 0) {
      return null;
    }
    // reveal(i) = offsetForIndex(i) + alignment * extent(i) + constant.
    final reference = range.$1;
    final constant =
        getOffsetToReveal(
          reference,
          alignment,
          alignmentOffset: alignmentOffset,
          obstruction: obstruction,
        ) -
        offsetForIndex(reference) -
        alignment * extentForIndex(reference).$1;
    double reveal(int i) =>
        offsetForIndex(i) + alignment * extentForIndex(i).$1 + constant;

    // Smallest index whose reveal offset is not before [scrollOffset].
    var low = 0;
    var high = count - 1;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (reveal(mid) < scrollOffset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    var best = low;
    if (low > 0 &&
        (reveal(low - 1) - scrollOffset).abs() <
            (reveal(low) - scrollOffset).abs()) {
      best = low - 1;
    }
    return ItemSnapTarget(index: best, offset: reveal(best));
  }
}

/// Position of an item within the viewport: the item is aligned like in
/// [ListController.jumpToItem].
class ItemPosition {
  const ItemPosition({
    required this.index,
    this.alignment = 0.0,
    this.alignmentOffset = 0.0,
  });

  /// Index of the item (items only, separators are not counted).
  final int index;

  /// 0.0 aligns the item to the leading edge of the viewport, 0.5 to the
  /// middle and 1.0 to the trailing edge.
  final double alignment;

  /// Additional shift in logical pixels towards the trailing edge.
  final double alignmentOffset;
}

/// Result of [ListController.snapTarget].
class ItemSnapTarget {
  const ItemSnapTarget({required this.index, required this.offset});

  /// Index of the item to snap to.
  final int index;

  /// Scroll offset at which the item is aligned.
  final double offset;

  @override
  String toString() => "ItemSnapTarget(index: $index, offset: $offset)";
}

typedef ExtentEstimationProvider =
    double Function(int? index, double crossAxisExtent);

abstract class ExtentPrecalculationPolicyDelegate {
  void valueDidChange();
}

class ExtentPrecalculationContext {
  ExtentPrecalculationContext({
    required this.viewportMainAxisExtent,
    required this.contentTotalExtent,
    required this.numberOfItems,
    required this.numberOfItemsWithEstimatedExtent,
  });

  /// The main axis extent of the viewport. May not be available initially.
  final double? viewportMainAxisExtent;

  /// The main axis extent of the content. May not be available initially.
  final double? contentTotalExtent;

  /// Number of items in the sliver.
  final int numberOfItems;

  /// Number of items in the sliver with estimated extent.
  final int numberOfItemsWithEstimatedExtent;
}

/// Subclass of [ExtentPrecalculationPolicy] can be used to control whether and
/// how many extents of the items in the list should be eagerly precalculated.
///
/// Extent precalculation may be helpful when precise scrollbar behavior is
/// desired. This is relevant for smaller lists, where the difference between
/// estimated and actual extents may affect the scrollbar position noticeably.
///
/// For larger lists, precalculating extents has diminishing benefits since the
/// difference between estimated and actual extent for each item has much
/// smaller impact on the scrollbar position.
///
/// There is no perfect answer for when or whether at all to precalculate
/// extents It depends on the specific application requirements.
abstract class ExtentPrecalculationPolicy {
  /// Called when the policy is attached to a [SuperSliverList]. Single policy may
  /// be attached to multiple [SuperSliverList]s.
  void onAttached() {}

  /// Called when the policy is detached from a [SuperSliverList].
  void onDetached() {}

  /// Called during layout to determine whether more extents should be precalculated.
  ///
  /// - If `true` is returned, the [SuperSliverList] will attempt to precalculate
  /// more extents for the list.
  /// - If `false is returned, the precalculation will stop.
  ///
  /// The [context] provides information about the current state of the list.
  ///
  /// If the conditions for precalculation change, the policy should call
  /// [valueDidChange] to notify the [SuperSliverList] that the policy has changed.
  bool shouldPrecalculateExtents(ExtentPrecalculationContext context);

  /// Notifies the [SuperSliverList] that the policy has changed. If the policy returned
  /// `false` from [shouldPrecalculateExtents] and then the condition changed and
  /// more extents should be precalculated, the policy calls [valueDidChange] to
  /// let the SliverList know that the policy has changed and the precalculation
  /// should be attempted again.
  void valueDidChange() {
    for (final delegate in _delegates) {
      delegate.valueDidChange();
    }
  }

  void addDelegate(ExtentPrecalculationPolicyDelegate? value) {
    _delegates.add(value!);
    if (_delegates.length == 1) {
      onAttached();
    }
  }

  void removeDelegate(ExtentPrecalculationPolicyDelegate? value) {
    _delegates.remove(value);
    if (_delegates.isEmpty) {
      onDetached();
    }
  }

  final _delegates = <ExtentPrecalculationPolicyDelegate>{};
}

/// Drop-in replacement for [SliverList] that can handle arbitrary large amount
/// of items with variable extent.
///
/// Through [listController] it [SuperSliverList] also provides a way to
/// jump to any item in the list, even if the item is not currently visible
/// or has not been laid out.
class SuperSliverList extends SliverMultiBoxAdaptorWidget {
  const SuperSliverList({
    super.key,
    required super.delegate,
    this.extentPrecalculationPolicy,
    this.listController,
    this.extentEstimation,
    this.delayPopulatingCacheArea = true,
    this.layoutKeptAliveChildren = false,
    this.stickToEnd = false,
    this.initialItem,
    this.scrollAnchoring = true,
    this.listControllerIndexesItems = false,
  });

  /// Creates a SuperSliverList from widget builder.
  ///
  /// See [SliverList.builder] for details.
  SuperSliverList.builder({
    super.key,
    required NullableIndexedWidgetBuilder itemBuilder,
    ChildIndexGetter? findChildIndexCallback,
    int? itemCount,
    this.extentPrecalculationPolicy,
    this.listController,
    this.extentEstimation,
    this.delayPopulatingCacheArea = true,
    this.layoutKeptAliveChildren = false,
    this.stickToEnd = false,
    this.initialItem,
    this.scrollAnchoring = true,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  }) : listControllerIndexesItems = false,
       super(
         delegate: SliverChildBuilderDelegate(
           itemBuilder,
           findChildIndexCallback: findChildIndexCallback,
           childCount: itemCount,
           addAutomaticKeepAlives: addAutomaticKeepAlives,
           addRepaintBoundaries: addRepaintBoundaries,
           addSemanticIndexes: addSemanticIndexes,
         ),
       );

  /// Creates a SuperSliverList from widget builder separated by separator
  /// widgets.
  ///
  /// See [SliverList.separated] for details.
  SuperSliverList.separated({
    super.key,
    required NullableIndexedWidgetBuilder itemBuilder,
    ChildIndexGetter? findChildIndexCallback,
    required NullableIndexedWidgetBuilder separatorBuilder,
    this.extentPrecalculationPolicy,
    this.listController,
    this.extentEstimation,
    this.delayPopulatingCacheArea = true,
    this.layoutKeptAliveChildren = false,
    this.stickToEnd = false,
    this.initialItem,
    this.scrollAnchoring = true,
    this.listControllerIndexesItems = true,
    int? itemCount,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  }) : super(
         delegate: SliverChildBuilderDelegate(
           (BuildContext context, int index) {
             final int itemIndex = index ~/ 2;
             final Widget? widget;
             if (index.isEven) {
               widget = itemBuilder(context, itemIndex);
             } else {
               widget = separatorBuilder(context, itemIndex);
               assert(() {
                 if (widget == null) {
                   throw FlutterError("separatorBuilder cannot return null.");
                 }
                 return true;
               }());
             }
             return widget;
           },
           findChildIndexCallback: findChildIndexCallback,
           childCount: itemCount == null
               ? null
               : math.max(0, itemCount * 2 - 1),
           addAutomaticKeepAlives: addAutomaticKeepAlives,
           addRepaintBoundaries: addRepaintBoundaries,
           addSemanticIndexes: addSemanticIndexes,
           semanticIndexCallback: (Widget _, int index) {
             return index.isEven ? index ~/ 2 : null;
           },
         ),
       );

  /// Creates a SuperSliverList from list of child widgets.
  ///
  /// See [SliverList.list] for details.
  SuperSliverList.list({
    super.key,
    required List<Widget> children,
    this.extentPrecalculationPolicy,
    this.listController,
    this.extentEstimation,
    this.delayPopulatingCacheArea = true,
    this.layoutKeptAliveChildren = false,
    this.stickToEnd = false,
    this.initialItem,
    this.scrollAnchoring = true,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  }) : listControllerIndexesItems = false,
       super(
         delegate: SliverChildListDelegate(
           children,
           addAutomaticKeepAlives: addAutomaticKeepAlives,
           addRepaintBoundaries: addRepaintBoundaries,
           addSemanticIndexes: addSemanticIndexes,
         ),
       );

  /// When set provides access to extents of individual children.
  /// [ListController] can also be used to jump to a specific item in the list.
  final ListController? listController;

  /// Whether the children alternate between items and separators, in which
  /// case the [listController] addresses items only: index `n` is the n-th item
  /// and separators are skipped.
  ///
  /// This is `true` by default for [SuperSliverList.separated]. Set it to
  /// `false` there to get the previous behavior, where the controller indexes
  /// all children (items at even indices, separators at odd indices).
  final bool listControllerIndexesItems;

  /// Optional method that can be used to override default estimated extent for
  /// each item. Initially all extents are estimated and then as the items are laid
  /// out, either through scrolling or [extentPrecalculationPolicy], the actual
  /// extents are calculated and the scroll offset is adjusted to account for
  /// the difference between estimated and actual extents.
  ///
  /// The item index argument is nullable. If all estimated items have same extent,
  /// the implementation should return non-zero extent for the `null` index. This saves
  /// calls to extent estimation provider for large lists.
  /// If each item has different extent, return zero for the `null` index.
  final ExtentEstimationProvider? extentEstimation;

  /// Optional policy that can be used to asynchronously precalculate the extents
  /// of the items in the list. This can be useful allow precise scrolling on small
  /// lists where the difference between estimated and actual extents may be noticeable
  /// when interacting with the scrollbar. For larger lists precalculating extent
  /// has diminishing benefits since the error for each item does not impact the
  /// overall scroll position as much.
  final ExtentPrecalculationPolicy? extentPrecalculationPolicy;

  /// Whether the items in cache area should be built delayed.
  /// This is an optimization that kicks in during fast scrolling, when
  /// all items are being replaced on every frame.
  /// With [delayPopulatingCacheArea] set to `true`, the items in cache area
  /// are only built after the scrolling slows down.
  final bool delayPopulatingCacheArea;

  /// Whether children with keepAlive should be laid out.
  /// Setting this to `true` ensures that layout for kept alive children is
  /// maintained and proper paint transform is applied.
  final bool layoutKeptAliveChildren;

  /// Keeps the end of the list in view: when the list grows (or its last item gets taller) while its end was visible, the scroll position follows the new end, as chat apps do. When the user scrolled away from the end the position is left alone. For reversed chat lists (newest item at index 0) use [ListController.addItem] with preserveScrollPosition instead.
  final bool stickToEnd;

  /// Item that is scrolled into view when the list first gets items, before the first frame is painted (no flash of the top of the list). Only applied once; ignored if the scroll position is not at 0 at that moment, for example because of a restored scroll offset. The list uses the same alignment as [ListController.jumpToItem].
  final ItemPosition? initialItem;

  /// Whether the list keeps the visible content in place when the extent of an item above it changes, for example because an image finished loading or a tile expanded. Similar to CSS scroll anchoring. The first fully visible item is the anchor.
  final bool scrollAnchoring;

  static SuperSliverListLayoutBudget layoutBudget =
      _TimeSuperSliverListLayoutBudget(budget: const Duration(milliseconds: 3));

  @override
  SliverMultiBoxAdaptorElement createElement() =>
      SuperSliverMultiBoxAdaptorElement(this, replaceMovedChildren: true);

  @override
  RenderSliverMultiBoxAdaptor createRenderObject(BuildContext context) {
    final element = context as SuperSliverMultiBoxAdaptorElement;
    return RenderSuperSliverList(
      childManager: element,
      extentPrecalculationPolicy: extentPrecalculationPolicy,
      estimateExtent: extentEstimation ?? _defaultEstimateExtent,
      delayPopulatingCacheArea: delayPopulatingCacheArea,
      layoutKeptAliveChildren: layoutKeptAliveChildren,
      scrollAnchoring: scrollAnchoring,
      initialItem: initialItem,
      stickToEnd: stickToEnd,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    final renderSliverList = renderObject as RenderSuperSliverList;
    renderSliverList.extentPrecalculationPolicy = extentPrecalculationPolicy;
    renderSliverList.estimateExtent =
        extentEstimation ?? _defaultEstimateExtent;
    renderSliverList.delayPopulatingCacheArea = delayPopulatingCacheArea;
    renderSliverList.layoutKeptAliveChildren = layoutKeptAliveChildren;
    renderSliverList.stickToEnd = stickToEnd;
    renderSliverList.initialItem = initialItem;
    renderSliverList.scrollAnchoring = scrollAnchoring;
  }
}

class _TimeSuperSliverListLayoutBudget extends SuperSliverListLayoutBudget {
  _TimeSuperSliverListLayoutBudget({required this.budget});

  @override
  void reset() {
    _stopwatch.reset();
  }

  @override
  void beginLayout() {
    _stopwatch.start();
  }

  @override
  void endLayout() {
    _stopwatch.stop();
  }

  @override
  bool shouldLayoutNextItem() {
    return _stopwatch.elapsed < budget;
  }

  final _stopwatch = Stopwatch();

  final Duration budget;
}

double _defaultEstimateExtent(int? index, double crossAxisExtent) {
  return 100.0;
}
