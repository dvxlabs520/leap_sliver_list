import "package:flutter/material.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "../util/sample_text.dart";

/// A grid of 10,000 cards with a different height each, built on
/// `SuperSliverGrid`, with jump and animate to any item.
class GridPage extends StatefulWidget {
  const GridPage({super.key});

  @override
  State<GridPage> createState() => _GridPageState();
}

class _GridPageState extends State<GridPage> {
  static const _itemCount = 10000;

  final _scrollController = ScrollController();
  final _gridController = GridController();

  int _columns = 3;
  double _target = 5000;

  int get _targetIndex => _target.round();

  @override
  void initState() {
    super.initState();
    // The visible range is known once the grid is attached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _gridController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Card.filled(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text("Columns"),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        for (final n in const [2, 3, 4, 6])
                          ButtonSegment(value: n, label: Text("$n")),
                      ],
                      selected: {_columns},
                      onSelectionChanged: (v) =>
                          setState(() => _columns = v.first),
                    ),
                    FilledButton(
                      onPressed: () => _gridController.jumpToItem(
                        index: _targetIndex,
                        scrollController: _scrollController,
                        alignment: 0,
                      ),
                      child: const Text("Jump"),
                    ),
                    FilledButton.tonal(
                      onPressed: () {
                        final index = _targetIndex;
                        _gridController.animateToItem(
                          index: () => index,
                          scrollController: _scrollController,
                          alignment: 0,
                          duration: (distance) => Duration(
                            milliseconds:
                                (distance / 20).clamp(400, 2500).round(),
                          ),
                          curve: (_) => Curves.easeInOutCubic,
                        );
                      },
                      child: const Text("Animate"),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text("Item $_targetIndex"),
                    Expanded(
                      child: Slider(
                        value: _target,
                        max: _itemCount - 1,
                        onChanged: (v) => setState(() => _target = v),
                      ),
                    ),
                  ],
                ),
                ListenableBuilder(
                  listenable: _scrollController,
                  builder: (context, _) {
                    final range = _gridController.isAttached
                        ? _gridController.visibleRange
                        : null;
                    return Text(
                      range == null
                          ? "Visible: -"
                          : "Visible: ${range.$1} to ${range.$2} of $_itemCount",
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SuperSliverGrid.builder(
                  controller: _gridController,
                  crossAxisCount: _columns,
                  itemCount: _itemCount,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  adaptiveEstimation: true,
                  itemBuilder: (context, index) => Card(
                    key: ValueKey("card-$index"),
                    margin: EdgeInsets.zero,
                    color: scheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Card $index",
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sampleText(index, 2 + hashed(index, 12)),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
