import "package:flutter/material.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "../util/sample_text.dart";

/// 10,000 items with a different height each, and every way of scrolling to
/// one of them: `jumpToItem`, `animateToItem`, alignment, pixel offset and
/// snapping.
class BigListPage extends StatefulWidget {
  const BigListPage({super.key});

  @override
  State<BigListPage> createState() => _BigListPageState();
}

class _BigListPageState extends State<BigListPage> {
  static const _itemCount = 10000;

  final _scrollController = ScrollController();
  final _listController = ListController();

  double _target = 5000;
  double _alignment = 0;
  double _alignmentOffset = 0;
  bool _snap = false;
  bool _adaptive = true;
  int? _highlighted;
  ItemAnimation? _animation;

  int get _targetIndex => _target.round();

  @override
  void dispose() {
    _scrollController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _jump() {
    setState(() => _highlighted = _targetIndex);
    _listController.jumpToItem(
      index: _targetIndex,
      scrollController: _scrollController,
      alignment: _alignment,
      alignmentOffset: _alignmentOffset,
    );
  }

  void _animate() {
    setState(() => _highlighted = _targetIndex);
    final index = _targetIndex;
    _animation = _listController.animateToItem(
      index: () => index,
      scrollController: _scrollController,
      alignment: _alignment,
      alignmentOffset: _alignmentOffset,
      duration: (distance) => Duration(
        milliseconds: (distance / 20).clamp(400, 2500).round(),
      ),
      curve: (_) => Curves.easeInOutCubic,
    );
  }

  void _cancel() {
    _animation?.cancel();
  }

  Widget _controls() {
    final textTheme = Theme.of(context).textTheme;
    return Card.filled(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SliderRow(
              label: "Item",
              value: _target,
              min: 0,
              max: _itemCount - 1,
              display: "$_targetIndex",
              onChanged: (v) => setState(() => _target = v),
            ),
            _SliderRow(
              label: "Alignment",
              value: _alignment,
              min: 0,
              max: 1,
              display: _alignment.toStringAsFixed(2),
              onChanged: (v) => setState(() => _alignment = v),
            ),
            _SliderRow(
              label: "Offset (px)",
              value: _alignmentOffset,
              min: -100,
              max: 100,
              display: _alignmentOffset.round().toString(),
              onChanged: (v) =>
                  setState(() => _alignmentOffset = v.roundToDouble()),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _jump,
                  icon: const Icon(Icons.bolt),
                  label: const Text("Jump"),
                ),
                FilledButton.tonalIcon(
                  onPressed: _animate,
                  icon: const Icon(Icons.animation),
                  label: const Text("Animate"),
                ),
                OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text("Cancel"),
                ),
                FilterChip(
                  label: const Text("Snap to items"),
                  selected: _snap,
                  onSelected: (v) => setState(() => _snap = v),
                ),
                FilterChip(
                  label: const Text("Adaptive estimation"),
                  selected: _adaptive,
                  onSelected: (v) => setState(() => _adaptive = v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: _scrollController,
              builder: (context, _) {
                final first = _listController.isAttached
                    ? _listController.firstVisibleIndex
                    : null;
                final last = _listController.isAttached
                    ? _listController.lastVisibleIndex
                    : null;
                final extent = _listController.isAttached
                    ? _listController.totalExtent
                    : 0.0;
                final position = _scrollController.hasClients
                    ? _scrollController.offset
                    : 0.0;
                return Text(
                  "Visible: ${first ?? "-"} to ${last ?? "-"}   "
                  "offset ${position.round()} px   "
                  "extent ${extent.round()} px",
                  style: textTheme.labelMedium,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _controls(),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            child: SuperListView.builder(
              controller: _scrollController,
              listController: _listController,
              adaptiveEstimation: _adaptive,
              physics: _snap
                  ? ItemSnapScrollPhysics(listController: _listController)
                  : null,
              itemCount: _itemCount,
              itemBuilder: (context, index) => _BigListItem(
                index: index,
                highlighted: index == _highlighted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(display, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _BigListItem extends StatelessWidget {
  const _BigListItem({required this.index, required this.highlighted});

  final int index;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = 1 + hashed(index, 7);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: highlighted ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Item $index",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(sampleText(index, lines * 9)),
          ],
        ),
      ),
    );
  }
}
