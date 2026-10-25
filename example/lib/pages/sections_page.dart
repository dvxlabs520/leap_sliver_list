import "package:flutter/material.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "../util/sample_text.dart";

/// Native sticky headers with `SuperStickyHeader`, and scrolling to an item
/// inside a section with any alignment.
class SectionsPage extends StatefulWidget {
  const SectionsPage({super.key});

  @override
  State<SectionsPage> createState() => _SectionsPageState();
}

class _SectionsPageState extends State<SectionsPage> {
  static const _sectionCount = 12;
  static const _itemsPerSection = 30;

  final _scrollController = ScrollController();
  final _listControllers = [
    for (var i = 0; i < _sectionCount; ++i) ListController(),
  ];

  int _section = 6;
  int _item = 15;
  double _alignment = 0.5;

  @override
  void dispose() {
    _scrollController.dispose();
    for (final controller in _listControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _go({required bool jump}) {
    final controller = _listControllers[_section];
    if (jump) {
      controller.jumpToItem(
        index: _item,
        scrollController: _scrollController,
        alignment: _alignment,
      );
    } else {
      controller.animateToItem(
        index: () => _item,
        scrollController: _scrollController,
        alignment: _alignment,
        duration: (_) => const Duration(milliseconds: 600),
        curve: (_) => Curves.easeInOut,
      );
    }
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
                    DropdownMenu<int>(
                      label: const Text("Section"),
                      initialSelection: _section,
                      onSelected: (v) => setState(() => _section = v ?? 0),
                      dropdownMenuEntries: [
                        for (var i = 0; i < _sectionCount; ++i)
                          DropdownMenuEntry(value: i, label: "Section $i"),
                      ],
                    ),
                    DropdownMenu<int>(
                      label: const Text("Item"),
                      initialSelection: _item,
                      onSelected: (v) => setState(() => _item = v ?? 0),
                      dropdownMenuEntries: [
                        for (var i = 0; i < _itemsPerSection; ++i)
                          DropdownMenuEntry(value: i, label: "Item $i"),
                      ],
                    ),
                    FilledButton(
                      onPressed: () => _go(jump: true),
                      child: const Text("Jump"),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _go(jump: false),
                      child: const Text("Animate"),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text("Alignment"),
                    Expanded(
                      child: Slider(
                        value: _alignment,
                        divisions: 4,
                        label: _alignment.toStringAsFixed(2),
                        onChanged: (v) => setState(() => _alignment = v),
                      ),
                    ),
                  ],
                ),
                Text(
                  "The item is aligned in the part of the viewport that the "
                  "sticky header does not cover, whatever the alignment.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              for (var s = 0; s < _sectionCount; ++s)
                SuperStickyHeader(
                  header: Material(
                    key: ValueKey("header-$s"),
                    color: scheme.secondaryContainer,
                    elevation: 1,
                    child: Container(
                      height: 44,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "Section $s",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                            ),
                      ),
                    ),
                  ),
                  sliver: SuperSliverList.builder(
                    listController: _listControllers[s],
                    itemCount: _itemsPerSection,
                    itemBuilder: (context, index) => ListTile(
                      title: Text("Section $s, item $index"),
                      subtitle: Text(
                        sampleText(
                            s * 100 + index, 3 + hashed(s * 50 + index, 14)),
                      ),
                      selected: s == _section && index == _item,
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
