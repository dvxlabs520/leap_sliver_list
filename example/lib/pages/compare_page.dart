import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "../util/sample_text.dart";
import "../widgets/frame_meter.dart";

enum _Implementation { flutter, leap }

/// The same 10,000 items in Flutter's `SliverList` and in `SuperSliverList`,
/// with a frame time meter. "Auto scroll" moves the list at a constant speed;
/// the jump button shows how precisely each one can reach an item.
class ComparePage extends StatefulWidget {
  const ComparePage({super.key});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage>
    with SingleTickerProviderStateMixin {
  static const _itemCount = 10000;
  static const _jumpTarget = 7500;
  // What a plain SliverList user would have to guess.
  static const _guessedItemExtent = 150.0;

  final _scrollController = ScrollController();
  final _listController = ListController();

  _Implementation _implementation = _Implementation.leap;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _direction = 1;
  double _speed = 4000;
  bool _autoScroll = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    var next = position.pixels + _direction * _speed * math.min(dt, 0.05);
    if (next >= position.maxScrollExtent) {
      next = position.maxScrollExtent;
      _direction = -1;
    } else if (next <= position.minScrollExtent) {
      next = position.minScrollExtent;
      _direction = 1;
    }
    position.jumpTo(next);
  }

  void _setAutoScroll(bool value) {
    setState(() => _autoScroll = value);
    if (value) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  void _jump() {
    if (_implementation == _Implementation.leap) {
      _listController.jumpToItem(
        index: _jumpTarget,
        scrollController: _scrollController,
        alignment: 0,
      );
    } else {
      _scrollController.jumpTo(_jumpTarget * _guessedItemExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leap = _implementation == _Implementation.leap;
    Widget itemBuilder(BuildContext context, int index) =>
        _CompareItem(index: index);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<_Implementation>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _Implementation.flutter,
                        label: Text("SliverList"),
                      ),
                      ButtonSegment(
                        value: _Implementation.leap,
                        label: Text("SuperSliverList"),
                      ),
                    ],
                    selected: {_implementation},
                    onSelectionChanged: (set) {
                      setState(() => _implementation = set.first);
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(0);
                      }
                    },
                  ),
                  FilterChip(
                    label: const Text("Auto scroll"),
                    selected: _autoScroll,
                    onSelected: _setAutoScroll,
                  ),
                  FilledButton.tonal(
                    onPressed: _jump,
                    child: Text(
                      leap
                          ? "Jump to item $_jumpTarget"
                          : "Jump to offset ${(_jumpTarget * _guessedItemExtent).round()}",
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text("Speed"),
                  Expanded(
                    child: Slider(
                      value: _speed,
                      min: 500,
                      max: 20000,
                      label: "${_speed.round()} px/s",
                      onChanged: (v) => setState(() => _speed = v),
                    ),
                  ),
                ],
              ),
              Text(
                leap
                    ? "SuperSliverList knows the extent of every item, so the "
                        "jump lands exactly on the item and the scrollbar is stable."
                    : "SliverList has no item index to offset mapping: the jump "
                        "guesses ${_guessedItemExtent.round()} px per item and lands "
                        "somewhere near.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              FrameMeter(
                key: ValueKey(_implementation),
                label: leap ? "SuperSliverList" : "SliverList",
              ),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            child: CustomScrollView(
              key: ValueKey(_implementation),
              controller: _scrollController,
              slivers: [
                if (leap)
                  SuperSliverList.builder(
                    listController: _listController,
                    itemCount: _itemCount,
                    itemBuilder: itemBuilder,
                  )
                else
                  SliverList.builder(
                    itemCount: _itemCount,
                    itemBuilder: itemBuilder,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompareItem extends StatelessWidget {
  const _CompareItem({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Item $index", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(sampleText(index, 6 + hashed(index, 60))),
          ],
        ),
      ),
    );
  }
}
