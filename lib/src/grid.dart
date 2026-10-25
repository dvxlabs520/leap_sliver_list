import "package:flutter/scheduler.dart";
import "package:flutter/widgets.dart";

import "animate_to_item.dart";
import "extent_manager.dart" show ItemTypeOf;
import "leap_sliver_list.dart";
import "sliver_extensions.dart";

/// Controls a [SuperSliverGrid]: scroll to an item by its index and find out
/// which items are visible.
///
/// Internally the grid is a [SuperSliverList] of rows, so this controller
/// translates item indices into rows and delegates to the [ListController] of
/// that list, which is available as [rows] if more control is needed (its
/// indices are row indices).
class GridController {
  GridController();

  /// Controller of the list of rows that makes up the grid.
  final ListController rows = ListController();

  int _crossAxisCount = 1;
  int _itemCount = 0;

  /// Whether the controller is attached to a [SuperSliverGrid].
  bool get isAttached => rows.isAttached;

  /// Number of items in each row.
  int get crossAxisCount => _crossAxisCount;

  /// Number of items of the grid.
  int get itemCount => _itemCount;

  /// Number of rows of the grid.
  int get rowCount => (_itemCount + _crossAxisCount - 1) ~/ _crossAxisCount;

  /// Row in which the item at [index] is.
  int rowOf(int index) => index ~/ _crossAxisCount;

  /// Column of the item at [index].
  int columnOf(int index) => index % _crossAxisCount;

  /// Range of the items that are at least partially visible, or `null` if
  /// nothing is visible. The first and last items of the range are those of the
  /// first and last visible rows, so the range may include items of those rows
  /// that are not visible.
  (int, int)? get visibleRange {
    final range = rows.visibleRange;
    if (range == null) {
      return null;
    }
    return (
      range.$1 * _crossAxisCount,
      ((range.$2 + 1) * _crossAxisCount - 1).clamp(0, _itemCount - 1),
    );
  }

  /// First item of the first visible row.
  int? get firstVisibleIndex => visibleRange?.$1;

  /// Last item of the last visible row.
  int? get lastVisibleIndex => visibleRange?.$2;

  /// Immediately scrolls such that the row of the item at [index] is revealed
  /// in the viewport. See [ListController.jumpToItem].
  void jumpToItem({
    required int index,
    required ScrollController scrollController,
    required double alignment,
    double alignmentOffset = 0.0,
    ChildObstructionExtent? obstruction,
  }) {
    rows.jumpToItem(
      index: rowOf(index),
      scrollController: scrollController,
      alignment: alignment,
      alignmentOffset: alignmentOffset,
      obstruction: obstruction,
    );
  }

  /// Animates the scroll view such that the row of the item at [index] is
  /// revealed in the viewport. See [ListController.animateToItem].
  ItemAnimation animateToItem({
    required ValueGetter<int?> index,
    required ScrollController scrollController,
    required double alignment,
    required Duration Function(double estimatedDistance) duration,
    required Curve Function(double estimatedDistance) curve,
    double alignmentOffset = 0.0,
    ChildObstructionExtent? obstruction,
  }) {
    return rows.animateToItem(
      index: () {
        final item = index();
        return item == null ? null : rowOf(item);
      },
      scrollController: scrollController,
      alignment: alignment,
      duration: duration,
      curve: curve,
      alignmentOffset: alignmentOffset,
      obstruction: obstruction,
    );
  }

  void dispose() {
    rows.dispose();
  }
}

/// A scrollable grid with a fixed number of columns whose rows can have any
/// height, built from a lazily built list so it can hold a very large number
/// of items. Use it as a sliver of a [CustomScrollView].
///
/// It is built on [SuperSliverList], where each row of the grid is an item.
/// Because of that, jumping and animating to an item (through
/// [GridController]) works like it does for a list, even for items that were
/// never laid out, and the grid can be placed in a [SuperStickyHeader].
///
/// Each row is as tall as its tallest cell and the cells are aligned to the top
/// of the row. Cells are not stretched to the height of the row and the grid
/// does not pack cells into the shortest column (a "masonry" layout). It only
/// scrolls in the vertical direction.
///
/// The number of columns is either fixed ([SuperSliverGrid.builder]) or follows
/// the width of the viewport ([SuperSliverGrid.extent]).
class SuperSliverGrid extends StatefulWidget {
  /// Creates a grid with [crossAxisCount] columns.
  const SuperSliverGrid.builder({
    super.key,
    required int this.crossAxisCount,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.extentPrecalculationPolicy,
    this.extentEstimation,
    this.adaptiveEstimation = false,
    this.scrollAnchoring = true,
    this.itemTypeOf,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
  }) : maxCrossAxisExtent = null,
       assert(crossAxisCount > 0);

  /// Creates a grid with as few columns as it takes to make each of them at
  /// most [maxCrossAxisExtent] wide (see
  /// [SliverGridDelegateWithMaxCrossAxisExtent]).
  const SuperSliverGrid.extent({
    super.key,
    required double this.maxCrossAxisExtent,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.extentPrecalculationPolicy,
    this.extentEstimation,
    this.adaptiveEstimation = false,
    this.scrollAnchoring = true,
    this.itemTypeOf,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
  }) : crossAxisCount = null,
       assert(maxCrossAxisExtent > 0);

  /// Number of columns, `null` if it depends on [maxCrossAxisExtent].
  final int? crossAxisCount;

  /// Maximum width of a column, `null` if the number of columns is fixed.
  final double? maxCrossAxisExtent;

  /// Number of items.
  final int itemCount;

  /// Builds the cell of the item at the given index.
  final NullableIndexedWidgetBuilder itemBuilder;

  /// Scrolls to items and reports the visible ones.
  final GridController? controller;

  /// Space between rows.
  final double mainAxisSpacing;

  /// Space between columns.
  final double crossAxisSpacing;

  /// See [SuperSliverList.extentPrecalculationPolicy]. It applies to rows.
  final ExtentPrecalculationPolicy? extentPrecalculationPolicy;

  /// See [SuperSliverList.extentEstimation]. The index is a row index.
  final ExtentEstimationProvider? extentEstimation;

  /// See [SuperSliverList.adaptiveEstimation].
  final bool adaptiveEstimation;

  /// See [SuperSliverList.scrollAnchoring].
  final bool scrollAnchoring;

  /// See [SuperSliverList.itemTypeOf]. The index is a row index.
  final ItemTypeOf? itemTypeOf;

  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;

  @override
  State<SuperSliverGrid> createState() => _SuperSliverGridState();
}

class _SuperSliverGridState extends State<SuperSliverGrid> {
  int? _columns;
  double? _spacing;

  @override
  void didUpdateWidget(SuperSliverGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _columns = null;
    }
  }

  /// The rows of the grid changed their content, the extents that were
  /// measured before are not valid anymore.
  void _invalidateExtents(GridController? controller) {
    if (controller == null) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.isAttached) {
        controller.rows.invalidateAllExtents();
      }
    });
  }

  Widget _buildGrid(BuildContext context, int columns) {
    final controller = widget.controller;
    if (controller != null) {
      controller
        .._crossAxisCount = columns
        .._itemCount = widget.itemCount;
    }
    final spacing = widget.mainAxisSpacing + widget.crossAxisSpacing;
    if ((_columns != null && _columns != columns) ||
        (_spacing != null && _spacing != spacing)) {
      _invalidateExtents(controller);
    }
    _columns = columns;
    _spacing = spacing;

    final itemCount = widget.itemCount;
    final rowCount = (itemCount + columns - 1) ~/ columns;
    return SuperSliverList.builder(
      listController: controller?.rows,
      itemCount: rowCount,
      extentPrecalculationPolicy: widget.extentPrecalculationPolicy,
      extentEstimation: widget.extentEstimation,
      adaptiveEstimation: widget.adaptiveEstimation,
      scrollAnchoring: widget.scrollAnchoring,
      itemTypeOf: widget.itemTypeOf,
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
      itemBuilder: (context, row) {
        final cells = <Widget>[];
        for (var column = 0; column < columns; ++column) {
          if (column > 0 && widget.crossAxisSpacing > 0) {
            cells.add(SizedBox(width: widget.crossAxisSpacing));
          }
          final index = row * columns + column;
          cells.add(
            Expanded(
              child: index < itemCount
                  ? (widget.itemBuilder(context, index) ??
                        const SizedBox.shrink())
                  : const SizedBox.shrink(),
            ),
          );
        }
        final child = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: cells,
        );
        if (widget.mainAxisSpacing > 0 && row < rowCount - 1) {
          return Padding(
            padding: EdgeInsets.only(bottom: widget.mainAxisSpacing),
            child: child,
          );
        }
        return child;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fixed = widget.crossAxisCount;
    if (fixed != null) {
      return _buildGrid(context, fixed);
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns =
            (constraints.crossAxisExtent /
                    (widget.maxCrossAxisExtent! + widget.crossAxisSpacing))
                .ceil()
                .clamp(1, 1 << 20);
        return _buildGrid(context, columns);
      },
    );
  }
}
