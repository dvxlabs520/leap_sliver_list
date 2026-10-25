import "dart:math" as math;

import "package:flutter/widgets.dart";

import "leap_sliver_list.dart";
import "sliver_extensions.dart";

/// Regular [RangeMaintainingScrollPhysics] will not keep the scroll position in range
/// when scroll position was corrected during the layout pass. That means removing
/// elements from the list will cause the scroll position to animate when it normally
/// wouldn't. As a workaround add [SuperRangeMaintainingScrollPhysics] to the physics
/// chain.
///
/// For example
/// ```dart
/// class _MyScrollBehavior extends ScrollBehavior {
///  const _MyScrollBehavior();
///
///  @override
///  ScrollPhysics getScrollPhysics(BuildContext context) {
///    return SuperRangeMaintainingScrollPhysics(
///        parent: super.getScrollPhysics(context));
///  }
/// }
/// ```
///
/// You can add use the [ScrollConfiguration] widget to apply the scroll behavior
/// to a subtree.
class SuperRangeMaintainingScrollPhysics extends ScrollPhysics {
  const SuperRangeMaintainingScrollPhysics({super.parent});

  @override
  SuperRangeMaintainingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SuperRangeMaintainingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (velocity == 0.0 && !oldPosition.outOfRange) {
      // [RangeMaintainingScrollPhysics] have a check where it compares
      // pixels to oldPixels, but that fails with scroll correction applied.
      oldPosition = oldPosition.copyWith(
        pixels: newPosition.pixels,
        minScrollExtent: math.min(
          newPosition.pixels,
          oldPosition.minScrollExtent,
        ),
        maxScrollExtent: math.max(
          newPosition.pixels,
          oldPosition.maxScrollExtent,
        ),
      );
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}

/// Scroll physics that snap to an item when scrolling ends: after a drag or
/// fling the list settles with an item aligned at [alignment] (see
/// [ListController.jumpToItem]), shifted by [alignmentOffset] pixels.
///
/// ```dart
/// SuperListView.builder(
///   listController: listController,
///   physics: ItemSnapScrollPhysics(listController: listController),
///   ...
/// )
/// ```
///
/// The item is picked from the position where a fling would have stopped, so
/// a strong fling still travels several items. Items are located with the
/// current extents of the list (estimated for items that were never laid out),
/// which is exact for the items near the viewport. Alignments between 0.0 and
/// 1.0 are supported.
class ItemSnapScrollPhysics extends ScrollPhysics {
  const ItemSnapScrollPhysics({
    required this.listController,
    this.alignment = 0.0,
    this.alignmentOffset = 0.0,
    this.obstruction,
    super.parent,
  });

  /// Controller of the list to snap to.
  final ListController listController;

  /// See [ListController.jumpToItem].
  final double alignment;

  /// See [ListController.jumpToItem].
  final double alignmentOffset;

  /// See [ListController.jumpToItem].
  final ChildObstructionExtent? obstruction;

  @override
  ItemSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ItemSnapScrollPhysics(
      listController: listController,
      alignment: alignment,
      alignmentOffset: alignmentOffset,
      obstruction: obstruction,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Out of range: let the parent bring the position back.
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent) ||
        position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    if (!listController.isAttached) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    var projected = position.pixels;
    if (velocity.abs() >= tolerance.velocity) {
      final fling = ClampingScrollSimulation(
        position: position.pixels,
        velocity: velocity,
        tolerance: tolerance,
      );
      projected = fling.x(double.maxFinite);
    }
    final target = listController.snapTarget(
      projected.clamp(position.minScrollExtent, position.maxScrollExtent),
      alignment: alignment,
      alignmentOffset: alignmentOffset,
      obstruction: obstruction,
    );
    if (target == null) {
      return super.createBallisticSimulation(position, velocity);
    }
    final offset = target.offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((offset - position.pixels).abs() < tolerance.distance) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      offset,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
