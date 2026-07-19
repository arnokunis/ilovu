// iLovuWidgetBundle.swift  (iLovuWidget target — the extension's @main entry)
// Registers the three iLovu home-screen widgets. This is the ONLY @main in the
// widget target; do not add it to the app target (the app has its own @main).

import WidgetKit
import SwiftUI

@main
struct iLovuWidgetBundle: WidgetBundle {
    var body: some Widget {
        DaysTogetherWidget()
        NextMissionWidget()
        LatestMemoryWidget()
    }
}
