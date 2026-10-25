import "dart:async";

import "package:flutter/material.dart";
import "package:leap_sliver_list/leap_sliver_list.dart";

import "../util/sample_text.dart";

class _Message {
  const _Message(this.id, this.text, this.mine);

  final int id;
  final String text;
  final bool mine;
}

/// A chat list: `stickToEnd` keeps the newest message in view while the user
/// is at the bottom, and older messages can be added above without moving
/// what is on screen.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _scrollController = ScrollController();
  final _listController = ListController();
  final _input = TextEditingController();

  final _messages = <_Message>[];
  int _nextId = 0;
  int _oldestId = 0;
  bool _stickToEnd = true;
  bool _autoReply = false;
  bool _atBottom = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 60; ++i) {
      _messages.add(_make(_nextId++));
    }
    _oldestId = 0;
    _scrollController.addListener(_onScroll);
  }

  _Message _make(int id) {
    return _Message(id, sampleText(id, 2 + hashed(id, 30)), hashed(id, 3) == 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    _listController.dispose();
    _input.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    final atBottom = position.maxScrollExtent - position.pixels < 40;
    if (atBottom != _atBottom) {
      setState(() => _atBottom = atBottom);
    }
  }

  void _addBottom({String? text, bool mine = false}) {
    setState(() {
      final id = _nextId++;
      _messages.add(
        text == null ? _make(id) : _Message(id, text, mine),
      );
    });
  }

  void _addTop() {
    const count = 10;
    setState(() {
      _messages.insertAll(0, [
        for (var i = 0; i < count; ++i) _make(--_oldestId),
      ]);
    });
    // Tell the list the items were added above the viewport, so it keeps the
    // visible messages where they are.
    _listController.addItem(0, count: count, preserveScrollPosition: true);
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) {
      return;
    }
    _input.clear();
    _addBottom(text: text, mine: true);
    // Sending always goes to the newest message.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (!_listController.isAttached || _messages.isEmpty) {
      return;
    }
    _listController.animateToItem(
      index: () => _messages.length - 1,
      scrollController: _scrollController,
      alignment: 1,
      duration: (_) => const Duration(milliseconds: 300),
      curve: (_) => Curves.easeOut,
    );
  }

  void _setAutoReply(bool value) {
    setState(() => _autoReply = value);
    _timer?.cancel();
    if (value) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) => _addBottom(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: const Text("Stick to end"),
                selected: _stickToEnd,
                onSelected: (v) => setState(() => _stickToEnd = v),
              ),
              FilterChip(
                label: const Text("Incoming messages"),
                selected: _autoReply,
                onSelected: _setAutoReply,
              ),
              OutlinedButton.icon(
                onPressed: _addBottom,
                icon: const Icon(Icons.arrow_downward),
                label: const Text("Add below"),
              ),
              OutlinedButton.icon(
                onPressed: _addTop,
                icon: const Icon(Icons.arrow_upward),
                label: const Text("Add 10 above"),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              SuperListView.builder(
                controller: _scrollController,
                listController: _listController,
                stickToEnd: _stickToEnd,
                adaptiveEstimation: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) =>
                    _Bubble(message: _messages[index]),
              ),
              Positioned(
                right: 16,
                bottom: 12,
                child: AnimatedScale(
                  scale: _atBottom ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: FloatingActionButton.small(
                    onPressed: _scrollToEnd,
                    tooltip: "Latest message",
                    child: const Icon(Icons.keyboard_double_arrow_down),
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: "Message",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _send,
                  tooltip: "Send",
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.7,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: mine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "#${message.id}",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                    ),
              ),
              Text(message.text),
            ],
          ),
        ),
      ),
    );
  }
}
