import "package:flutter/material.dart" show Colors;
import "package:leap_sliver_list/leap_sliver_list.dart";
import "package:pixel_snap/widgets.dart";

import "../shell/example_page.dart";
import "../widgets/button.dart";

/// Shows `stickToEnd`, `adaptiveEstimation`, `SuperStickyHeader`,
/// `initialItem` and item snapping.
class ChatSectionsPage extends StatefulWidget {
  const ChatSectionsPage({super.key});

  @override
  State<ChatSectionsPage> createState() => _ChatSectionsPageState();
}

class _ChatSectionsPageState extends ExamplePageState<ChatSectionsPage> {
  @override
  Widget? createSidebarWidget() => null;

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _Chat()),
        Expanded(child: _Sections()),
        Expanded(child: _Snap()),
      ],
    );
  }
}

class _Chat extends StatefulWidget {
  const _Chat();

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final _messages = <String>[
    for (var i = 0; i < 40; ++i) "Message $i ${"word " * (i % 7 * 6)}",
  ];

  void _send() {
    setState(() => _messages.add("Message ${_messages.length}"));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Expanded(
                child: Text("Chat: stickToEnd + adaptiveEstimation"),
              ),
              Button(onPressed: _send, child: const Text("Send")),
            ],
          ),
        ),
        Expanded(
          child: SuperListView.builder(
            // The list starts at the newest message, and follows new ones
            // while the end is in view. Scroll up and it stays where it is.
            stickToEnd: true,
            adaptiveEstimation: true,
            itemCount: _messages.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.all(6),
              child: Text(_messages[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _Sections extends StatefulWidget {
  const _Sections();

  @override
  State<_Sections> createState() => _SectionsState();
}

class _SectionsState extends State<_Sections> {
  final _scrollController = ScrollController();
  final _listControllers = [for (var i = 0; i < 5; ++i) ListController()];

  @override
  void dispose() {
    _scrollController.dispose();
    for (final controller in _listControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Expanded(child: Text("SuperStickyHeader")),
              Button(
                onPressed: () => _listControllers[3].animateToItem(
                  index: () => 20,
                  scrollController: _scrollController,
                  alignment: 0.5,
                  duration: (_) => const Duration(milliseconds: 400),
                  curve: (_) => Curves.easeInOut,
                ),
                child: const Text("Section 3, item 20"),
              ),
            ],
          ),
        ),
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              for (var section = 0; section < 5; ++section)
                SuperStickyHeader(
                  header: Container(
                    height: 40,
                    color: Colors.blue.shade100,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text("Section $section"),
                  ),
                  sliver: SuperSliverList.builder(
                    listController: _listControllers[section],
                    itemCount: 40,
                    itemBuilder: (context, index) => Container(
                      height: 40.0 + index % 4 * 12,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text("Section $section, item $index"),
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

class _Snap extends StatefulWidget {
  const _Snap();

  @override
  State<_Snap> createState() => _SnapState();
}

class _SnapState extends State<_Snap> {
  final _listController = ListController();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text("ItemSnapScrollPhysics + initialItem"),
        ),
        Expanded(
          child: SuperListView.builder(
            listController: _listController,
            // Starts with item 50 at the leading edge, and settles on the
            // leading edge of an item after every fling.
            initialItem: const ItemPosition(index: 50),
            physics: ItemSnapScrollPhysics(listController: _listController),
            itemCount: 1000,
            itemBuilder: (context, index) => Container(
              height: 50.0 + index % 5 * 20,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text("Item $index"),
            ),
          ),
        ),
      ],
    );
  }
}
