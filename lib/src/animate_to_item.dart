import "dart:async";
import "dart:ui";

import "package:flutter/scheduler.dart";
import "package:flutter/widgets.dart";

import "extent_manager.dart";
import "sliver_extensions.dart";

/// Handle for an animation started by [ListController.animateToItem].
///
/// The handle is a [Future] that completes (never with an error) when the
/// animation is over, no matter whether it reached the item or was stopped:
///
/// ```dart
/// await listController.animateToItem(...);
/// ```
///
/// Use [isCanceled] to find out if the animation was stopped before reaching
/// the item. An animation is canceled by [cancel], by the user scrolling the
/// list, by starting another animation or jump on the same scroll position,
/// when the index getter returns `null` or when the list is removed from the
/// tree.
class ItemAnimation implements Future<void> {
  ItemAnimation._(this._parts)
    : _future = Future.wait(_parts.map((part) => part.done)).then((_) {});

  /// Creates an animation with the given parts that has to be started
  /// afterwards (internal).
  factory ItemAnimation.internal(List<AnimateToItem> parts) =>
      ItemAnimation._(parts);

  final List<AnimateToItem> _parts;
  final Future<void> _future;

  /// Whether the animation is over, either because it reached the item or
  /// because it was canceled.
  bool get isCompleted => _parts.every((part) => part.isFinished);

  /// Whether the animation was stopped before reaching the item.
  bool get isCanceled =>
      _parts.isEmpty || _parts.any((part) => part.isCanceled);

  /// Stops the animation at the current scroll position. Does nothing if the
  /// animation is already over.
  void cancel() {
    for (final part in _parts) {
      part.cancel();
    }
  }

  @override
  Stream<void> asStream() => _future.asStream();

  @override
  Future<void> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) => _future.catchError(onError, test: test);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(void value) onValue, {
    Function? onError,
  }) => _future.then(onValue, onError: onError);

  @override
  Future<void> timeout(
    Duration timeLimit, {
    FutureOr<void> Function()? onTimeout,
  }) => _future.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<void> whenComplete(FutureOr<void> Function() action) =>
      _future.whenComplete(action);
}

/// Animation of a single [ScrollPosition] to an item.
class AnimateToItem {
  AnimateToItem({
    required this.extentManager,
    required this.index,
    required this.alignment,
    required this.rect,
    this.obstruction,
    required this.position,
    required this.duration,
    required this.curve,
    this.onFinished,
  });

  final ExtentManager extentManager;
  final ValueGetter<int?> index;
  final double alignment;
  final Rect? rect;
  final ChildObstructionExtent? obstruction;
  final ScrollPosition position;
  final Duration Function(double estimatedDistance) duration;
  final Curve Function(double estimatedDistance) curve;
  final VoidCallback? onFinished;

  final _done = Completer<void>();
  AnimationController? _controller;
  CurvedAnimation? _animation;
  bool _isCanceled = false;
  bool _notifying = false;
  double _start = 0.0;

  /// Completes when the animation finishes or is canceled.
  Future<void> get done => _done.future;

  bool get isFinished => _done.isCompleted;
  bool get isCanceled => _isCanceled;

  void start() {
    assert(!isFinished && _controller == null);
    final index = this.index();
    if (index == null) {
      _finish(canceled: true);
      return;
    }
    _start = position.pixels;
    final estimatedTarget = extentManager.getOffsetToReveal(
      index,
      alignment,
      rect: rect,
      obstruction: obstruction,
      estimationOnly: true,
    );
    final estimatedDistance = (estimatedTarget - _start).abs();
    final controller = AnimationController(
      vsync: position.context.vsync,
      duration: duration(estimatedDistance),
    );
    _controller = controller;
    controller.addStatusListener(_onStatus);
    _animation = CurvedAnimation(
      parent: controller,
      curve: curve(estimatedDistance),
    )..addListener(_onTick);
    // Scrolling that did not originate from this animation (dragging,
    // mouse wheel, scrollbar, ...) takes over.
    position.isScrollingNotifier.addListener(_onScrollingChanged);
    controller.forward();
  }

  /// Stops the animation at the current position.
  void cancel() {
    _finish(canceled: true);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _finish(canceled: false);
    }
  }

  void _onScrollingChanged() {
    if (position.isScrollingNotifier.value) {
      cancel();
    }
  }

  void _onTick() {
    if (isFinished) {
      return;
    }
    if (!position.hasPixels) {
      cancel();
      return;
    }
    final index = this.index();
    if (index == null) {
      cancel();
      return;
    }
    final value = _animation!.value;
    var targetPosition = extentManager.getOffsetToReveal(
      index,
      alignment,
      rect: rect,
      obstruction: obstruction,
      estimationOnly: value < 1.0,
    );
    if (value < 1.0) {
      // Clamp position during animation to prevent overscroll.
      targetPosition = targetPosition.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
    }
    final jumpPosition = lerpDouble(_start, targetPosition, value)!;
    if ((jumpPosition <= position.minScrollExtent &&
            position.pixels == position.minScrollExtent) ||
        (jumpPosition >= position.maxScrollExtent &&
            position.pixels == position.maxScrollExtent)) {
      // Do not jump when already at the edge. This prevents scrollbar handle artifacts.
      return;
    }
    _notifying = true;
    try {
      position.jumpTo(jumpPosition);
    } finally {
      _notifying = false;
    }
  }

  void _finish({required bool canceled}) {
    if (isFinished) {
      return;
    }
    _isCanceled = canceled;
    position.isScrollingNotifier.removeListener(_onScrollingChanged);
    final controller = _controller;
    final animation = _animation;
    _controller = null;
    _animation = null;
    if (controller != null) {
      controller.stop();
      // Disposing while the controller is notifying its listeners is not safe,
      // postpone in that case.
      void dispose() {
        animation?.dispose();
        controller.dispose();
      }

      if (_inNotification) {
        scheduleMicrotask(dispose);
      } else {
        dispose();
      }
    }
    _done.complete();
    onFinished?.call();
  }

  // The status and value listeners are invoked from within the ticker
  // callback, which runs in the transient callbacks phase.
  bool get _inNotification =>
      _notifying ||
      SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.transientCallbacks;
}
