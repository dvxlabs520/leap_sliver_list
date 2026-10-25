import "dart:math" as math;
import "dart:ui";

import "package:flutter/foundation.dart";

import "extent_list.dart";
import "sliver_extensions.dart";

/// Returns the kind of the item at the given index, see
/// [SuperSliverList.itemTypeOf].
typedef ItemTypeOf = Object Function(int index);

abstract class ExtentManagerDelegate {
  const ExtentManagerDelegate();

  void onMarkNeedsLayout();
  double estimateExtentForItem(int? index);
  double getOffsetToReveal(
    int index,
    double alignment, {
    required bool estimationOnly,
    Rect? rect,
    ChildObstructionExtent? obstruction,
  });
}

class ExtentManager with ChangeNotifier {
  ExtentManager({required this.delegate});

  double _beforeCorrection = 0.0;
  double _afterCorrection = 0.0;

  final ExtentManagerDelegate delegate;

  /// When `true` the extent of items that were not measured yet follows the
  /// average of the items measured so far, instead of the delegate estimate.
  bool adaptiveEstimation = false;

  /// Returns the kind of the item at the given index. When set (together with
  /// [adaptiveEstimation]), items that were not measured yet are estimated
  /// with the average of the measured items of the same kind.
  ItemTypeOf? get itemTypeOf => _itemTypeOf;
  set itemTypeOf(ItemTypeOf? value) {
    if ((value == null) != (_itemTypeOf == null)) {
      _typeEstimates.clear();
      _lastReestimateCount = 0;
    }
    _itemTypeOf = value;
  }

  ItemTypeOf? _itemTypeOf;

  double? _adaptiveEstimate;
  int _lastReestimateCount = 0;

  // Average extent of the measured items of each type.
  final _typeEstimates = <Object, double>{};

  static const _separatorType = Object();

  /// Type of the child at [index]. The manager works with child indices,
  /// while [itemTypeOf] works with item indices.
  Object _typeOfChild(int index) {
    if (separated) {
      return index.isOdd ? _separatorType : _itemTypeOf!(index ~/ 2);
    }
    return _itemTypeOf!(index);
  }

  double _estimateForItem(int? index) {
    final adaptive = _adaptiveEstimate;
    if (adaptiveEstimation && adaptive != null) {
      if (_itemTypeOf != null && _typeEstimates.isNotEmpty) {
        // The estimate depends on the item, see ExtentList.resize.
        return index == null
            ? 0.0
            : _typeEstimates[_typeOfChild(index)] ?? adaptive;
      }
      return adaptive;
    }
    return delegate.estimateExtentForItem(index);
  }

  /// Updates the estimated extent of items that were not measured yet if the
  /// average of the measured items differs from the current estimate. This
  /// is only done when the number of measured items has doubled since the last
  /// time, so the total cost stays linear.
  ///
  /// Returns the change of the offset of the item at [index]
  /// (which is the sum of the changes of the extents before it).
  double reestimateIfNeeded(int index) {
    if (!adaptiveEstimation) {
      return 0.0;
    }
    final count = _extentList.measuredCount;
    if (count < _minMeasuredForReestimation ||
        count < _lastReestimateCount * 2) {
      if (count < _lastReestimateCount) {
        _lastReestimateCount = count;
      }
      return 0.0;
    }
    _lastReestimateCount = count;
    final average = _extentList.averageMeasuredExtent!;
    final current = _adaptiveEstimate ?? delegate.estimateExtentForItem(null);
    if (_itemTypeOf != null) {
      return _reestimateByType(index, average, current);
    }
    if (average <= 0 ||
        (average - current).abs() <= current * _reestimationThreshold) {
      return 0.0;
    }
    final before = index < _extentList.length
        ? _extentList.offsetForIndex(index)
        : 0.0;
    _adaptiveEstimate = average;
    _extentList.reestimateDirty(average);
    _isModified = true;
    final after = index < _extentList.length
        ? _extentList.offsetForIndex(index)
        : 0.0;
    return after - before;
  }

  double _reestimateByType(int index, double average, double current) {
    final sums = <Object, double>{};
    final counts = <Object, int>{};
    _extentList.forEachMeasured((i, extent) {
      final type = _typeOfChild(i);
      sums[type] = (sums[type] ?? 0.0) + extent;
      counts[type] = (counts[type] ?? 0) + 1;
    });
    final estimates = <Object, double>{
      for (final type in sums.keys) type: sums[type]! / counts[type]!,
    };
    var changed = false;
    for (final entry in estimates.entries) {
      final previous = _typeEstimates[entry.key] ?? current;
      if (entry.value > 0 &&
          (entry.value - previous).abs() > previous * _reestimationThreshold) {
        changed = true;
        break;
      }
    }
    if (!changed || average <= 0) {
      return 0.0;
    }
    final before = index < _extentList.length
        ? _extentList.offsetForIndex(index)
        : 0.0;
    _typeEstimates
      ..clear()
      ..addAll({
        for (final entry in estimates.entries)
          if (entry.value > 0) entry.key: entry.value,
      });
    _adaptiveEstimate = average;
    _extentList.reestimateDirtyWith(
      (i) => _typeEstimates[_typeOfChild(i)] ?? average,
    );
    _isModified = true;
    final after = index < _extentList.length
        ? _extentList.offsetForIndex(index)
        : 0.0;
    return after - before;
  }

  static const _minMeasuredForReestimation = 6;
  static const _reestimationThreshold = 0.05;

  /// Whether children alternate between items and separators. The manager
  /// itself always works with child indices; [ListController] uses this flag
  /// to translate the item indices of its public API.
  bool separated = false;

  double get correctionPercentage => _afterCorrection / _beforeCorrection;

  void setExtent(int index, double extent, {bool isEstimation = false}) {
    if (!isEstimation) {
      _beforeCorrection += _extentList[index];
      _afterCorrection += extent;
    }
    _extentList.setExtent(index, extent, isEstimation: isEstimation);
    _isModified = true;
  }

  void markAllDirty() {
    _afterCorrection = 0.0;
    _beforeCorrection = 0.0;
    _isModified = true;
    _lastReestimateCount = 0;
    _extentList.markAllDirty();
  }

  bool get hasDirtyItems => _extentList.hasDirtyItems;

  double get totalExtent => _extentList.totalExtent;

  int? get cleanRangeStart => _extentList.cleanRangeStart;
  int? get cleanRangeEnd => _extentList.cleanRangeEnd;

  @pragma("vm:prefer-inline")
  double getExtent(int index) => _extentList[index];

  void resize(int newSize) {
    if (newSize == _extentList.length) {
      return;
    }
    _isModified = true;
    _extentList.resize(newSize, _estimateForItem);
  }

  final _extentList = ExtentList();

  int? indexForOffset(double offset) {
    return _extentList.indexForOffset(offset);
  }

  double offsetForIndex(int index) {
    assert(index >= 0 && index < _extentList.length);
    return _extentList.offsetForIndex(index);
  }

  (double, bool) extentForIndex(int index) {
    return (_extentList[index], _extentList.isDirty(index));
  }

  bool _layoutInProgress = false;
  bool _isModified = false;

  bool _didReportVisibleChildren = false;
  bool _didReportUnobstructedVisibleChildren = false;

  void performLayout(VoidCallback layout) {
    assert(!_layoutInProgress);
    _layoutInProgress = true;
    _isModified = false;
    _didReportVisibleChildren = false;
    _didReportUnobstructedVisibleChildren = false;
    _beforeCorrection = 0.0;
    _afterCorrection = 0.0;

    try {
      layout();
    } finally {
      assert(_layoutInProgress);
      // Not reporting children means there are no visible children - set the
      // visible range to null.
      if (!_didReportVisibleChildren) {
        reportVisibleChildren(null);
      }
      if (!_didReportUnobstructedVisibleChildren) {
        reportUnobstructedVisibleChildren(null);
      }
      _layoutInProgress = false;
      if (_isModified) {
        notifyListeners();
      }
    }
  }

  void reportVisibleChildren((int, int)? range) {
    assert(_layoutInProgress);
    if (_visibleRange != range) {
      _visibleRange = range;
      _isModified = true;
    }
    _didReportVisibleChildren = true;
  }

  void reportUnobstructedVisibleChildren((int, int)? range) {
    assert(_layoutInProgress);
    if (_unobstructedVisibleRange != range) {
      _unobstructedVisibleRange = range;
      _isModified = true;
    }
    _didReportUnobstructedVisibleChildren = true;
  }

  (int, int)? get visibleRange => _visibleRange;
  (int, int)? _visibleRange;

  (int, int)? get unobstructedVisibleRange => _unobstructedVisibleRange;
  (int, int)? _unobstructedVisibleRange;

  int get numberOfItems => _extentList.length;

  int get numberOfItemsWithEstimatedExtent => _extentList.dirtyItemCount;

  void addItem(
    int index, {
    int count = 1,
    bool preserveScrollPosition = false,
  }) {
    for (var i = 0; i < count; ++i) {
      _extentList.insertAt(index, _estimateForItem);
    }
    if (preserveScrollPosition && count > 0) {
      _pendingInsertions.add((index, count));
    }
    delegate.onMarkNeedsLayout();
  }

  final _pendingInsertions = <(int, int)>[];

  /// Maximum number of inserted items that are measured to determine the
  /// scroll offset correction. The remaining ones use estimated extents.
  static const _maxMeasuredInsertedItems = 256;

  /// Returns (and clears) the total extent of the items inserted with
  /// `preserveScrollPosition` that are located before [scrollOffset].
  ///
  /// The inserted items are measured with [measure] so that the correction is
  /// exact and not just based on estimated extents.
  double takeInsertionCorrection(
    double scrollOffset, {
    required double Function(int index) measure,
  }) {
    if (_pendingInsertions.isEmpty) {
      return 0.0;
    }
    var correction = 0.0;
    final pending = _pendingInsertions.toList();
    _pendingInsertions.clear();
    for (final (index, count) in pending) {
      if (index >= _extentList.length ||
          _extentList.offsetForIndex(index) > scrollOffset) {
        continue;
      }
      final end = math.min(index + count, _extentList.length);
      for (var i = index; i < end; ++i) {
        if (i - index < _maxMeasuredInsertedItems) {
          setExtent(i, measure(i));
        }
        correction += _extentList[i];
      }
    }
    return correction;
  }

  void removeItem(int index) {
    _extentList.removeAt(index);
    delegate.onMarkNeedsLayout();
  }

  void invalidateExtent(int index) {
    _extentList.markDirty(index);
    delegate.onMarkNeedsLayout();
  }

  void invalidateAllExtents() {
    _lastReestimateCount = 0;
    _extentList.markAllDirty();
    delegate.onMarkNeedsLayout();
  }

  bool get isLocked => _layoutInProgress;

  double getOffsetToReveal(
    int index,
    double alignment, {
    Rect? rect,
    required bool estimationOnly,
    ChildObstructionExtent? obstruction,
  }) {
    return delegate.getOffsetToReveal(
      index,
      alignment,
      rect: rect,
      obstruction: obstruction,
      estimationOnly: estimationOnly,
    );
  }

  @override
  String toString() {
    return "ExtentManager ${identityHashCode(this).toRadixString(16)}";
  }
}
