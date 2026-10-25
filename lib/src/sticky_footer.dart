import "dart:math" as math;

import "package:flutter/rendering.dart";
import "package:flutter/widgets.dart";

/// Pins [footer] to the trailing edge of the viewport for as long as [sliver]
/// (usually a [SuperSliverList]) extends beyond it.
///
/// This is the counterpart of [SuperStickyHeader]: the footer sits right
/// after the last item of the sliver, but while the end of the sliver is still
/// out of view, it stays at the end of the viewport (the bottom of a vertical
/// list). When the end of the sliver is scrolled into view the footer scrolls
/// away with it, and the next sliver takes the trailing edge.
///
/// The footer is laid out with a tight cross axis and an unconstrained main
/// axis, so it takes the height (width) of its own content. It paints and
/// receives hit tests on top of the sliver.
///
/// A [SuperSliverList] inside takes the footer into account when a jump or an
/// animation aligns an item: the item is aligned within the part of the
/// viewport that is not covered by the footer.
///
/// It can be combined with [SuperStickyHeader]:
///
/// ```dart
/// SuperStickyHeader(
///   header: header,
///   sliver: SuperStickyFooter(footer: footer, sliver: list),
/// )
/// ```
///
/// Only slivers that grow forward are supported (that is always the case for
/// the slivers of a plain [CustomScrollView]).
class SuperStickyFooter
    extends
        SlottedMultiChildRenderObjectWidget<StickyFooterSlot, RenderObject> {
  const SuperStickyFooter({
    super.key,
    required this.footer,
    required this.sliver,
  });

  /// Widget pinned to the trailing edge. It must be a box widget.
  final Widget footer;

  /// The sliver the footer belongs to.
  final Widget sliver;

  @override
  Iterable<StickyFooterSlot> get slots => StickyFooterSlot.values;

  @override
  Widget? childForSlot(StickyFooterSlot slot) {
    return switch (slot) {
      StickyFooterSlot.sliver => sliver,
      StickyFooterSlot.footer => footer,
    };
  }

  @override
  RenderSliverStickyFooter createRenderObject(BuildContext context) {
    return RenderSliverStickyFooter();
  }
}

/// Children of [SuperStickyFooter].
enum StickyFooterSlot { sliver, footer }

/// Render object of [SuperStickyFooter].
class RenderSliverStickyFooter extends RenderSliver
    with
        SlottedContainerRenderObjectMixin<StickyFooterSlot, RenderObject>,
        RenderSliverHelpers {
  RenderSliver? get _sliver =>
      childForSlot(StickyFooterSlot.sliver) as RenderSliver?;

  RenderBox? get _footer => childForSlot(StickyFooterSlot.footer) as RenderBox?;

  /// The wrapped sliver.
  RenderSliver? get sliverChild => _sliver;

  /// Distance in the main axis between the start of this sliver's painted
  /// region and the footer, as seen along the growth direction.
  double _footerPosition = 0.0;

  /// Main axis extent of the footer.
  double get footerExtent {
    final footer = _footer;
    if (footer == null || !footer.hasSize) {
      return 0.0;
    }
    return constraints.axis == Axis.vertical
        ? footer.size.height
        : footer.size.width;
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverPhysicalParentData) {
      child.parentData = SliverPhysicalParentData();
    }
  }

  @override
  double? childScrollOffset(RenderObject child) {
    if (child == _footer) {
      return _sliver?.geometry?.scrollExtent ?? 0.0;
    }
    return 0.0;
  }

  @override
  double childMainAxisPosition(RenderObject child) {
    if (child == _footer) {
      return _footerPosition;
    }
    final sliver = child as RenderSliver;
    final childParentData = sliver.parentData! as SliverPhysicalParentData;
    return switch (applyGrowthDirectionToAxisDirection(
      sliver.constraints.axisDirection,
      sliver.constraints.growthDirection,
    )) {
      AxisDirection.down => childParentData.paintOffset.dy,
      AxisDirection.right => childParentData.paintOffset.dx,
      AxisDirection.up =>
        geometry!.paintExtent -
            sliver.geometry!.paintExtent -
            childParentData.paintOffset.dy,
      AxisDirection.left =>
        geometry!.paintExtent -
            sliver.geometry!.paintExtent -
            childParentData.paintOffset.dx,
    };
  }

  @override
  double childCrossAxisPosition(RenderObject child) => 0.0;

  @override
  void performLayout() {
    final sliver = _sliver;
    final footer = _footer;
    if (sliver == null || footer == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    assert(
      constraints.growthDirection == GrowthDirection.forward,
      "SuperStickyFooter only supports slivers that grow forward.",
    );

    footer.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    final double footerExtent = this.footerExtent;

    sliver.layout(constraints, parentUsesSize: true);
    final SliverGeometry childGeometry = sliver.geometry!;
    final double? correction = childGeometry.scrollOffsetCorrection;
    if (correction != null) {
      geometry = SliverGeometry(scrollOffsetCorrection: correction);
      return;
    }

    final double childExtent = childGeometry.scrollExtent;
    final double scrollExtent = childExtent + footerExtent;
    final double paintExtent = calculatePaintOffset(
      constraints,
      from: 0.0,
      to: scrollExtent,
    );
    final double cacheExtent = calculateCacheOffset(
      constraints,
      from: 0.0,
      to: scrollExtent,
    );

    // Where the footer would be if it simply followed the last item, and
    // where it has to be to touch the trailing edge of the viewport.
    final double natural = childExtent - constraints.scrollOffset;
    final double pinned = constraints.remainingPaintExtent - footerExtent;
    _footerPosition = natural <= pinned ? natural : math.max(pinned, 0.0);

    geometry = SliverGeometry(
      scrollExtent: scrollExtent,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: scrollExtent,
      hitTestExtent: paintExtent,
      hasVisualOverflow: true,
      maxScrollObstructionExtent: childGeometry.maxScrollObstructionExtent,
    );

    final childPaintOrigin = childGeometry.paintOrigin;
    final childData = sliver.parentData! as SliverPhysicalParentData;
    final footerData = footer.parentData! as SliverPhysicalParentData;
    switch (applyGrowthDirectionToAxisDirection(
      constraints.axisDirection,
      constraints.growthDirection,
    )) {
      case AxisDirection.down:
        childData.paintOffset = Offset(0.0, childPaintOrigin);
        footerData.paintOffset = Offset(0.0, _footerPosition);
      case AxisDirection.right:
        childData.paintOffset = Offset(childPaintOrigin, 0.0);
        footerData.paintOffset = Offset(_footerPosition, 0.0);
      case AxisDirection.up:
        childData.paintOffset = Offset(
          0.0,
          paintExtent - childPaintOrigin - childGeometry.paintExtent,
        );
        footerData.paintOffset = Offset(
          0.0,
          paintExtent - _footerPosition - footerExtent,
        );
      case AxisDirection.left:
        childData.paintOffset = Offset(
          paintExtent - childPaintOrigin - childGeometry.paintExtent,
          0.0,
        );
        footerData.paintOffset = Offset(
          paintExtent - _footerPosition - footerExtent,
          0.0,
        );
    }
  }

  bool get _footerVisible {
    final footer = _footer;
    if (footer == null || geometry == null || geometry!.paintExtent <= 0.0) {
      return false;
    }
    final double extent = footerExtent;
    return _footerPosition + extent > 0.0 &&
        _footerPosition < geometry!.paintExtent;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final sliver = _sliver;
    final footer = _footer;
    if (sliver != null && sliver.geometry!.visible) {
      final data = sliver.parentData! as SliverPhysicalParentData;
      context.paintChild(sliver, offset + data.paintOffset);
    }
    if (footer != null && _footerVisible) {
      final data = footer.parentData! as SliverPhysicalParentData;
      context.paintChild(footer, offset + data.paintOffset);
    }
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final data = child.parentData! as SliverPhysicalParentData;
    data.applyPaintTransform(transform);
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    final sliver = _sliver;
    final footer = _footer;
    if (footer != null && _footerVisible) {
      final hit = hitTestBoxChild(
        BoxHitTestResult.wrap(result),
        footer,
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
      );
      if (hit) {
        return true;
      }
    }
    if (sliver != null && sliver.geometry!.hitTestExtent > 0.0) {
      final data = sliver.parentData! as SliverPhysicalParentData;
      return result.addWithAxisOffset(
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
        paintOffset: data.paintOffset,
        mainAxisOffset: childMainAxisPosition(sliver),
        crossAxisOffset: childCrossAxisPosition(sliver),
        hitTest: sliver.hitTest,
      );
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final sliver = _sliver;
    final footer = _footer;
    if (sliver != null &&
        (sliver.geometry!.visible ||
            sliver.geometry!.cacheExtent > 0.0 ||
            sliver.ensureSemantics)) {
      visitor(sliver);
    }
    if (footer != null && _footerVisible) {
      visitor(footer);
    }
  }
}
