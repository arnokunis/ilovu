# iLovu Widgets — Xcode setup (the parts I can't do headless)

The widget **code is written**. It won't compile into anything until the target
and App Group exist. Do these steps once in Xcode + the Apple Developer portal,
then the three widgets work.

## 1. Register an App Group (Apple Developer portal)

The app and the widget share data through an App Group container.

1. https://developer.apple.com → Certificates, Identifiers & Profiles → Identifiers.
2. **App Groups** → **＋** → create `group.com.ilovu.app`
   (must exactly match `WidgetShared.appGroupId` in `iLovu/WidgetShared.swift`).

## 2. Create the Widget Extension target (Xcode)

1. `File ▸ New ▸ Target… ▸ Widget Extension`.
2. Product name: **iLovuWidget**. Uncheck "Include Configuration App Intent"
   (these are static widgets). Uncheck "Include Live Activity". Finish.
   Activate the scheme if prompted.
3. Xcode generates a starter `iLovuWidget.swift` in a new `iLovuWidget` group.
   **Delete that generated file** (move to Trash) — our staged files replace it.

## 3. Add the staged source files to the target

The real widget code already lives in the repo's `iLovuWidget/` folder:

- `iLovuWidgetBundle.swift`  (the `@main`)
- `LovuProvider.swift`       (timeline provider + shared style)
- `DaysTogetherWidget.swift`
- `NextMissionWidget.swift`
- `LatestMemoryWidget.swift`

In Xcode: right-click the `iLovuWidget` group ▸ **Add Files to "iLovu"…** ▸ select
those five files ▸ set **Target = iLovuWidget only** (NOT the app) ▸ Add.

## 4. Share the ONE common file with both targets

`iLovu/WidgetShared.swift` must belong to **both** targets:

1. Select `iLovu/WidgetShared.swift` in the navigator.
2. File inspector (right panel) ▸ **Target Membership** ▸ tick **both**
   `iLovu` **and** `iLovuWidget`.

(Keep `WidgetDataWriter.swift` on the **app target only** — it uses UIKit/ImageCache.)

## 5. Turn on the App Group capability for both targets

For **each** target (`iLovu` and `iLovuWidget`):

1. Target ▸ **Signing & Capabilities** ▸ **＋ Capability** ▸ **App Groups**.
2. Tick `group.com.ilovu.app`.

This adds the entitlement so `WidgetShared.containerURL` becomes non-nil and the
writer starts producing snapshots.

## 6. Set the widget deployment target

Set the `iLovuWidget` target's **minimum deployment** to match the app (the code
uses `containerBackground`, iOS 17+).

## 7. Build & run

1. Build the **iLovu** app scheme once and launch it (pair / have a couple with a
   dating date + a mission + a memory, so there's data to show).
2. Long-press the home screen ▸ **＋** ▸ search **iLovu** ▸ add
   Days Together / Next Date / Latest Memory.

The app rewrites the snapshot whenever the couple, missions, or memories change
(`iLovuApp`'s `.task(id: widgetDigest)`), then calls `WidgetCenter.reloadAllTimelines()`.

## Notes / gotchas

- Until step 5 is done, everything **no-ops gracefully** — no crash, app behaves
  exactly as before (`containerURL == nil`).
- `SWIFT_USE_INTEGRATED_DRIVER = NO` is set on the app for the Xcode 26.6 driver
  crash — if the widget target hits the same SIGTRAP, set the same flag on it.
- Latest Memory shows its photo only when the image is available locally (own
  capture, or an already-downloaded partner memory). Otherwise it shows the
  text card — by design, so the widget never blocks on a network fetch.
