import "package:flutter/material.dart";

import "pages/anchoring_page.dart";
import "pages/big_list_page.dart";
import "pages/chat_page.dart";
import "pages/compare_page.dart";
import "pages/grid_page.dart";
import "pages/sections_page.dart";

class _Destination {
  const _Destination(this.title, this.icon, this.builder);

  final String title;
  final IconData icon;
  final WidgetBuilder builder;
}

final _destinations = <_Destination>[
  _Destination(
    "Big list",
    Icons.view_list_outlined,
    (_) => const BigListPage(),
  ),
  _Destination(
    "Chat",
    Icons.chat_bubble_outline,
    (_) => const ChatPage(),
  ),
  _Destination(
    "Sections",
    Icons.vertical_split_outlined,
    (_) => const SectionsPage(),
  ),
  _Destination(
    "Grid",
    Icons.grid_view_outlined,
    (_) => const GridPage(),
  ),
  _Destination(
    "Anchoring",
    Icons.anchor,
    (_) => const AnchoringPage(),
  ),
  _Destination(
    "Compare",
    Icons.speed,
    (_) => const ComparePage(),
  ),
];

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: brightness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "leap_sliver_list demo",
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _themeMode,
      home: _Home(
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.themeMode, required this.onThemeModeChanged});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final destination = _destinations[_selected];
    final body = KeyedSubtree(
      key: ValueKey(_selected),
      child: destination.builder(context),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(destination.title),
        actions: [
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                tooltip: "Light theme",
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                tooltip: "System theme",
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                tooltip: "Dark theme",
              ),
            ],
            selected: {widget.themeMode},
            onSelectionChanged: (set) => widget.onThemeModeChanged(set.first),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selected,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _selected = i),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        label: Text(d.title),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selected,
              onDestinationSelected: (i) => setState(() => _selected = i),
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.title),
              ],
            ),
    );
  }
}
