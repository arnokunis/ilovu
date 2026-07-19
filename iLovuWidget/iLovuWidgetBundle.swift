//
//  iLovuWidgetBundle.swift
//  iLovuWidget
//
// The extension's @main entry — registers the three iLovu home-screen widgets.
// This is the ONLY @main in the widget target.

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
