import "package:flutter/widgets.dart";

/// A sliver that pins [header] to the leading edge of the viewport while
/// [sliver] (typically a [SuperSliverList]) scrolls underneath it. When the end
/// of [sliver] is reached the header is pushed out of the viewport, so
/// consecutive [SuperStickyHeader]s replace each other like the sections of a
/// contacts list.
///
/// This is a thin composition of Flutter's own [SliverMainAxisGroup] and
/// [PinnedHeaderSliver], it does not depend on any other package. The
/// [ListController] methods that scroll to an item (`jumpToItem`,
/// `animateToItem`, `getOffsetToReveal`) know about the header: the item is
/// aligned within the part of the viewport that is not covered by it, so
/// **do not pass an `obstruction` for this header**, it would be counted twice.
///
/// Only a header at the leading edge is supported. Headers of other packages,
/// such as `flutter_sticky_header`, still work by passing the header extent as
/// `obstruction` to the [ListController] methods.
///
/// ```dart
/// CustomScrollView(
///   slivers: [
///     for (final section in sections)
///       SuperStickyHeader(
///         header: SectionHeader(section),
///         sliver: SuperSliverList.builder(
///           itemCount: section.items.length,
///           itemBuilder: (context, index) => ItemTile(section.items[index]),
///         ),
///       ),
///   ],
/// )
/// ```
class SuperStickyHeader extends StatelessWidget {
  const SuperStickyHeader({
    super.key,
    required this.header,
    required this.sliver,
  });

  /// Box widget that is pinned to the leading edge of the viewport. It gets
  /// the full cross axis extent and sizes itself in the main axis.
  final Widget header;

  /// The sliver that scrolls underneath the header.
  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        PinnedHeaderSliver(child: header),
        sliver,
      ],
    );
  }
}
