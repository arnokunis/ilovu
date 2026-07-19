# iLovu Widgets — remaining setup

Target created ✅ · App Group registered in portal ✅ · template files removed +
bundle fixed ✅. Because the `iLovuWidget` target uses a **synchronized folder
group**, every `.swift` file in `iLovuWidget/` is already a member of the widget
target — no manual "Add Files" needed.

Two steps left, both in Xcode:

## A. Share `WidgetShared.swift` with the widget target  (the critical one)

`iLovu/WidgetShared.swift` is the one file both the app and the widget need.

1. Select **`iLovu/WidgetShared.swift`** in the navigator.
2. Open the **File Inspector** (right panel, ⌥⌘1).
3. Under **Target Membership**, tick **both** `iLovu` **and** `iLovuWidgetExtension`.

(Leave `WidgetDataWriter.swift` on the app target only — it uses UIKit/ImageCache.)

## B. Add the App Group capability to BOTH targets

For **each** target — `iLovu` and `iLovuWidgetExtension`:

1. Target ▸ **Signing & Capabilities** ▸ **＋ Capability** ▸ **App Groups**.
2. Tick **`group.com.ilovu.app`** (the identifier you registered — not the description).

This writes the entitlement so `WidgetShared.containerURL` becomes non-nil and the
app starts producing widget snapshots.

## C. Build & run

1. Build/run the **iLovu** app scheme on a device/simulator that has a couple with a
   dating date + a mission + a memory (so there's data to show).
2. Long-press the home screen ▸ **＋** ▸ search **iLovu** ▸ add
   Days Together / Next Date / Latest Memory.

## Notes

- Until step B is done everything **no-ops gracefully** — no crash; the app behaves
  exactly as before (`containerURL == nil`).
- If the widget target hits the Xcode 26.6 `SWBBuildService` SIGTRAP, set
  `SWIFT_USE_INTEGRATED_DRIVER = NO` on the `iLovuWidgetExtension` target too (the
  app already has it).
- Confirm the widget target's **min deployment ≤ 18.5** (it uses `containerBackground`,
  iOS 17+ — fine at 18.5).
