# leap_sliver_list demo

A Material 3 demo of the package, with a light/dark/system theme switch.

| Page | What it shows |
| --- | --- |
| Big list | 10,000 items of different heights: `jumpToItem`, `animateToItem`, cancel, alignment, pixel offset, `ItemSnapScrollPhysics`, adaptive estimation. |
| Chat | `stickToEnd`, adding messages below, and older messages above with `addItem(..., preserveScrollPosition: true)`. |
| Sections | `SuperStickyHeader` with 12 sections, and scrolling to an item below the header with any alignment. |
| Anchoring | Items that grow above the viewport, with `scrollAnchoring` on and off. |
| Compare | `SliverList` and `SuperSliverList` side by side with a frame time meter, auto scroll and a jump to item 7500. |

```sh
flutter run -d chrome --profile
```

The frame time meter is only meaningful in a profile or release build.
Tests: `flutter test`.
