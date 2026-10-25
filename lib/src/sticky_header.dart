import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter/scheduler.dart";
import "package:flutter/widgets.dart";

/// Tells which [SuperStickyHeader] is the active one: the last header whose
/// section has reached the leading edge of the viewport, which is the one that
/// is pinned (or being pushed out by the next one).
///
/// The [value] is the `index` of that header. It is the lowest index until the
/// list is scrolled to the second section, and `null` while no header is
/// attached. Listeners are notified after the frame in which the pinned
/// header changed, never during layout, and only when the value changes.
///
/// Give each header of a list the same controller and a different `index`. A
/// controller must be disposed by its owner.
class StickyHeaderController extends ChangeNotifier
    implements ValueListenable<int?> {
  StickyHeaderController();

  final _attached = <int>{};
  final _reached = <int>{};
  int? _value;
  bool _updateScheduled = false;

  @override
  int? get value => _value;

  int? get _candidate {
    if (_attached.isEmpty) {
      return null;
    }
    var result = _attached.reduce(math.min);
    for (final index in _reached) {
      if (_attached.contains(index) && index > result) {
        result = index;
      }
    }
    return result;
  }

  void _attach(int index) {
    _attached.add(index);
    _scheduleUpdate();
  }

  void _detach(int index) {
    _attached.remove(index);
    _reached.remove(index);
    _scheduleUpdate();
  }

  void _report(int index, {required bool reached}) {
    final changed = reached ? _reached.add(index) : _reached.remove(index);
    if (changed) {
      _scheduleUpdate();
    }
  }

  void _scheduleUpdate() {
    if (_updateScheduled) {
      return;
    }
    _updateScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (_disposed) {
        return;
      }
      final candidate = _candidate;
      if (candidate != _value) {
        _value = candidate;
        notifyListeners();
      }
    });
    // Make sure the callback runs when this is called outside of a frame.
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

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
/// Pass a [StickyHeaderController] and an [index] to find out which header is
/// the pinned one, for example to highlight the current section in a side
/// index.
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
class SuperStickyHeader extends StatefulWidget {
  const SuperStickyHeader({
    super.key,
    required this.header,
    required this.sliver,
    this.controller,
    this.index,
  }) : assert(
         controller == null || index != null,
         "index is required when a controller is given",
       );

  /// Box widget that is pinned to the leading edge of the viewport. It gets
  /// the full cross axis extent and sizes itself in the main axis. It is
  /// marked as a header for accessibility services.
  final Widget header;

  /// The sliver that scrolls underneath the header.
  final Widget sliver;

  /// Reports whether this header is the active one, see
  /// [StickyHeaderController].
  final StickyHeaderController? controller;

  /// Identifies this header in [controller]. Must be unique among the
  /// headers that share the controller, and increase in scroll order.
  final int? index;

  @override
  State<SuperStickyHeader> createState() => _SuperStickyHeaderState();
}

class _SuperStickyHeaderState extends State<SuperStickyHeader> {
  @override
  void initState() {
    super.initState();
    widget.controller?._attach(widget.index!);
  }

  @override
  void didUpdateWidget(SuperStickyHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.index != widget.index) {
      oldWidget.controller?._detach(oldWidget.index!);
      widget.controller?._attach(widget.index!);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(widget.index!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final group = SliverMainAxisGroup(
      slivers: [
        PinnedHeaderSliver(
          child: Semantics(header: true, container: true, child: widget.header),
        ),
        widget.sliver,
      ],
    );
    if (controller == null) {
      return group;
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        // The group has reached the top when it was scrolled, or when it
        // sits exactly at the leading edge (nothing else takes space before
        // it).
        controller._report(
          widget.index!,
          reached:
              constraints.scrollOffset > precisionErrorTolerance ||
              constraints.remainingPaintExtent >=
                  constraints.viewportMainAxisExtent - precisionErrorTolerance,
        );
        return group;
      },
    );
  }
}
