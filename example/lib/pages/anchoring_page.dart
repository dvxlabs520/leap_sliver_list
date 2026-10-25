import "package:flutter/material.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "../util/sample_text.dart";

/// Items that grow while they are above the viewport (an image that finishes
/// loading, a section that expands). With scroll anchoring on, the content
/// that is visible stays where it is. Turn it off to see the jump.
class AnchoringPage extends StatefulWidget {
  const AnchoringPage({super.key});

  @override
  State<AnchoringPage> createState() => _AnchoringPageState();
}

class _AnchoringPageState extends State<AnchoringPage> {
  static const _itemCount = 300;

  final _scrollController = ScrollController();
  final _listController = ListController();
  final _expanded = <int>{};

  bool _anchoring = true;

  @override
  void initState() {
    super.initState();
    // Start in the middle, so there is room above.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listController.jumpToItem(
        index: 100,
        scrollController: _scrollController,
        alignment: 0,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _toggle(int index) {
    setState(() {
      if (!_expanded.remove(index)) {
        _expanded.add(index);
      }
    });
  }

  void _expandAbove() {
    final first = _listController.firstVisibleIndex;
    if (first == null) {
      return;
    }
    setState(() {
      for (var i = first - 1; i >= 0 && i >= first - 2; --i) {
        _expanded.add(i);
      }
    });
  }

  void _collapseAll() {
    setState(_expanded.clear);
  }

  @override
  Widget build(BuildContext context) {
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
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text("Scroll anchoring"),
                      selected: _anchoring,
                      onSelected: (v) => setState(() => _anchoring = v),
                    ),
                    FilledButton.tonal(
                      onPressed: _expandAbove,
                      child: const Text("Expand 2 items above the view"),
                    ),
                    OutlinedButton(
                      onPressed: _collapseAll,
                      child: const Text("Collapse all"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Tap an item to expand it. The button grows the two items "
                  "right above the first visible one, as if their images "
                  "had just loaded.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SuperListView.builder(
            controller: _scrollController,
            listController: _listController,
            scrollAnchoring: _anchoring,
            itemCount: _itemCount,
            itemBuilder: (context, index) => _ExpandableItem(
              index: index,
              expanded: _expanded.contains(index),
              onTap: () => _toggle(index),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpandableItem extends StatelessWidget {
  const _ExpandableItem({
    required this.index,
    required this.expanded,
    required this.onTap,
  });

  final int index;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Item $index",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    sampleText(index, 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
